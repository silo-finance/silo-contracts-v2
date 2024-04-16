// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {SafeERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import {ISilo, IERC4626, IERC3156FlashLender, ILiquidationProcess} from "./interfaces/ISilo.sol";
import {ISiloOracle} from "./interfaces/ISiloOracle.sol";
import {IShareToken} from "./interfaces/IShareToken.sol";

import {IERC3156FlashBorrower} from "./interfaces/IERC3156FlashBorrower.sol";
import {ILeverageBorrower} from "./interfaces/ILeverageBorrower.sol";
import {ISiloConfig} from "./interfaces/ISiloConfig.sol";
import {ISiloFactory} from "./interfaces/ISiloFactory.sol";
import {IInterestRateModel} from "./interfaces/IInterestRateModel.sol";
import {IHookReceiver} from "./utils/hook-receivers/interfaces/IHookReceiver.sol";

import {SiloERC4626} from "./utils/SiloERC4626.sol";
import {SiloStdLib} from "./lib/SiloStdLib.sol";
import {SiloSolvencyLib} from "./lib/SiloSolvencyLib.sol";
import {SiloLendingLib} from "./lib/SiloLendingLib.sol";
import {SiloERC4626Lib} from "./lib/SiloERC4626Lib.sol";
import {SiloMathLib} from "./lib/SiloMathLib.sol";
import {LiquidationWithdrawLib} from "./lib/LiquidationWithdrawLib.sol";
import {Rounding} from "./lib/Rounding.sol";
import {Methods} from "./lib/Methods.sol";
import {CrossEntrancy} from "./lib/CrossEntrancy.sol";
import {Hook} from "./lib/Hook.sol";

// Keep ERC4626 ordering
// solhint-disable ordering

/// @title Silo vault with lending and borrowing functionality
/// @notice Silo is a ERC4626-compatible vault that allows users to deposit collateral and borrow debt. This contract
/// is deployed twice for each asset for two-asset lending markets.
/// Version: 2.0.0
contract Silo is Initializable, SiloERC4626 {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    bytes32 internal constant _LEVERAGE_CALLBACK = keccak256("ILeverageBorrower.onLeverage");

    ISiloFactory public immutable factory;

    ISiloConfig public config;

    SiloData public siloData;

    /// @dev silo is just for one asset, but this one asset can be of three types, so we store `assets` by type. We use
    /// struct instead of uint256 to pass storage reference to functions.
    /// `total` can have outdated value (without interest), if you doing view call (of off-chain call) please use
    /// getters eg `getCollateralAssets()` to fetch value that includes interest.
    mapping(AssetType => Assets) public override total;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(ISiloFactory _siloFactory) {
        _disableInitializers();
        factory = _siloFactory;
    }

    /// @inheritdoc ISilo
    function initialize(ISiloConfig _siloConfig, address _modelConfigAddress) external virtual initializer {
        config = _siloConfig;

        address interestRateModel = _siloConfig.getConfig(address(this)).interestRateModel;
        IInterestRateModel(interestRateModel).connect(_modelConfigAddress);
    }

    /// @inheritdoc ISilo
    function utilizationData() external view virtual returns (UtilizationData memory) {
        return UtilizationData({
            collateralAssets: total[AssetType.Collateral].assets,
            debtAssets: total[AssetType.Debt].assets,
            interestRateTimestamp: siloData.interestRateTimestamp
        });
    }

    function getLiquidity() external view virtual returns (uint256 liquidity) {
        return SiloLendingLib.getLiquidity(config);
    }

    /// @inheritdoc ISilo
    function isSolvent(address _borrower) external view virtual returns (bool) {
        (
            ISiloConfig.ConfigData memory collateral,
            ISiloConfig.ConfigData memory debt,
            ISiloConfig.DebtInfo memory debtInfo
        ) = config.getConfigs(address(this), _borrower, Hook.NONE);

        return SiloSolvencyLib.isSolvent(collateral, debt, debtInfo, _borrower, AccrueInterestInMemory.Yes);
    }

    /// @inheritdoc ISilo
    function getCollateralAssets() external view virtual returns (uint256 totalCollateralAssets) {
        ISiloConfig.ConfigData memory thisSiloConfig = config.getConfig(address(this));

        totalCollateralAssets = SiloStdLib.getTotalCollateralAssetsWithInterest(
            thisSiloConfig.silo,
            thisSiloConfig.interestRateModel,
            thisSiloConfig.daoFee,
            thisSiloConfig.deployerFee
        );
    }

    /// @inheritdoc ISilo
    function getDebtAssets() external view virtual returns (uint256 totalDebtAssets) {
        ISiloConfig.ConfigData memory thisSiloConfig = config.getConfig(address(this));

        totalDebtAssets = SiloStdLib.getTotalDebtAssetsWithInterest(
            thisSiloConfig.silo, thisSiloConfig.interestRateModel
        );
    }

    /// @inheritdoc ISilo
    function getCollateralAndProtectedAssets()
        external
        view
        virtual
        returns (uint256 totalCollateralAssets, uint256 totalProtectedAssets)
    {
        totalCollateralAssets = total[AssetType.Collateral].assets;
        totalProtectedAssets = total[AssetType.Protected].assets;
    }

    /// @inheritdoc ISilo
    function getCollateralAndDebtAssets()
        external
        view
        virtual
        returns (uint256 totalCollateralAssets, uint256 totalDebtAssets)
    {
        totalCollateralAssets = total[AssetType.Collateral].assets;
        totalDebtAssets = total[AssetType.Debt].assets;
    }

    // ERC4626

    /// @inheritdoc IERC4626
    function asset() external view virtual returns (address assetTokenAddress) {
        return config.getAssetForSilo(address(this));
    }

    /// @inheritdoc IERC4626
    function totalAssets() external view virtual returns (uint256 totalManagedAssets) {
        (totalManagedAssets,) = _getTotalAssetsAndTotalSharesWithInterest(AssetType.Collateral);
    }

    /// @inheritdoc IERC4626
    /// @dev For protected (non-borrowable) collateral and debt, use:
    /// `convertToShares(uint256 _assets, AssetType _assetType)` with `AssetType.Protected` or `AssetType.Debt`
    function convertToShares(uint256 _assets) external view virtual returns (uint256 shares) {
        (uint256 totalSiloAssets, uint256 totalShares) =
            _getTotalAssetsAndTotalSharesWithInterest(AssetType.Collateral);

        return SiloMathLib.convertToShares(
            _assets, totalSiloAssets, totalShares, Rounding.DEFAULT_TO_SHARES, AssetType.Collateral
        );
    }

    /// @inheritdoc IERC4626
    /// @dev For protected (non-borrowable) collateral and debt, use:
    /// `convertToAssets(uint256 _shares, AssetType _assetType)` with `AssetType.Protected` or `AssetType.Debt`
    function convertToAssets(uint256 _shares) external view virtual returns (uint256 assets) {
        (uint256 totalSiloAssets, uint256 totalShares) =
            _getTotalAssetsAndTotalSharesWithInterest(AssetType.Collateral);

        return SiloMathLib.convertToAssets(
            _shares, totalSiloAssets, totalShares, Rounding.DEFAULT_TO_ASSETS, AssetType.Collateral
        );
    }

    /// @inheritdoc IERC4626
    function maxDeposit(address /* _receiver */) external view virtual returns (uint256 maxAssets) {
        return _callMaxDepositOrMint(total[AssetType.Collateral].assets);
    }

    /// @inheritdoc IERC4626
    function previewDeposit(uint256 _assets) external view virtual returns (uint256 shares) {
        return _previewDeposit(_assets, AssetType.Collateral);
    }

    /// @inheritdoc IERC4626
    function deposit(uint256 _assets, address _receiver)
        external
        virtual
        returns (uint256 shares)
    {
        (, shares) = _deposit(_assets, 0 /* shares */, _receiver, AssetType.Collateral);
    }

    /// @inheritdoc IERC4626
    function maxMint(address /* _receiver */) external view virtual returns (uint256 maxShares) {
        return _callMaxDepositOrMint(IShareToken(_getShareToken()).totalSupply());
    }

    /// @inheritdoc IERC4626
    function previewMint(uint256 _shares) external view virtual returns (uint256 assets) {
        return _previewMint(_shares, AssetType.Collateral);
    }

    /// @inheritdoc IERC4626
    function mint(uint256 _shares, address _receiver) external virtual returns (uint256 assets) {
        (assets,) = _deposit(0 /* assets */, _shares, _receiver, AssetType.Collateral);
    }

    /// @inheritdoc IERC4626
    function maxWithdraw(address _owner) external view virtual returns (uint256 maxAssets) {
        (maxAssets,) = _callMaxWithdraw(config, _owner, AssetType.Collateral);
    }

    /// @inheritdoc IERC4626
    function previewWithdraw(uint256 _assets) external view virtual returns (uint256 shares) {
        return _previewWithdraw(_assets, AssetType.Collateral);
    }

    /// @inheritdoc IERC4626
    function withdraw(uint256 _assets, address _receiver, address _owner)
        external
        virtual
        returns (uint256 shares)
    {
        (, shares) = _withdraw(WithdrawParams(_assets, 0 /* shares */, _receiver, _owner, msg.sender, AssetType.Collateral));
    }

    /// @inheritdoc IERC4626
    function maxRedeem(address _owner) external view virtual returns (uint256 maxShares) {
        (, maxShares) = _callMaxWithdraw(config, _owner, AssetType.Collateral);
    }

    /// @inheritdoc IERC4626
    function previewRedeem(uint256 _shares) external view virtual returns (uint256 assets) {
        return _previewRedeem(_shares, AssetType.Collateral);
    }

    /// @inheritdoc IERC4626
    function redeem(uint256 _shares, address _receiver, address _owner)
        external
        virtual
        returns (uint256 assets)
    {
        // avoid magic number 0
        uint256 zeroAssets = 0;

        (assets,) = _withdraw(WithdrawParams(zeroAssets, _shares, _receiver, _owner, msg.sender, AssetType.Collateral));
    }

    /// @inheritdoc ISilo
    function convertToShares(uint256 _assets, AssetType _assetType) external view virtual returns (uint256 shares) {
        (uint256 totalSiloAssets, uint256 totalShares) = _getTotalAssetsAndTotalSharesWithInterest(_assetType);

        return SiloMathLib.convertToShares(
            _assets, totalSiloAssets, totalShares, Rounding.DEFAULT_TO_SHARES, _assetType
        );
    }

    /// @inheritdoc ISilo
    function convertToAssets(uint256 _shares, AssetType _assetType) external view virtual returns (uint256 assets) {
        (uint256 totalSiloAssets, uint256 totalShares) = _getTotalAssetsAndTotalSharesWithInterest(_assetType);

        return SiloMathLib.convertToAssets(
            _shares,
            totalSiloAssets,
            totalShares,
            _assetType == AssetType.Debt ? Rounding.DEBT_TO_ASSETS : Rounding.DEFAULT_TO_ASSETS,
            _assetType
        );
    }

    /// @inheritdoc ISilo
    function maxDeposit(address /* _receiver */, AssetType _assetType)
        external
        view
        virtual
        returns (uint256 maxAssets)
    {
        return _callMaxDepositOrMint(total[_assetType].assets);
    }

    /// @inheritdoc ISilo
    function previewDeposit(uint256 _assets, AssetType _assetType) external view virtual returns (uint256 shares) {
        return _previewDeposit(_assets, _assetType);
    }

    /// @inheritdoc ISilo
    function deposit(uint256 _assets, address _receiver, AssetType _assetType)
        external
        virtual
        returns (uint256 shares)
    {
        (, shares) = _deposit(_assets, 0, /* shares */ _receiver, _assetType);
    }

    /// @inheritdoc ISilo
    function maxMint(address /* _receiver */, AssetType _assetType)
        external
        view
        virtual
        returns (uint256 maxShares)
    {
        if (_assetType == AssetType.Debt) revert ISilo.WrongAssetType();

        (address protectedToken, address collateralToken, ) = config.getShareTokens(address(this));
        address shareToken = _assetType == AssetType.Collateral ? collateralToken : protectedToken;

        return _callMaxDepositOrMint(IShareToken(shareToken).totalSupply());
    }

    /// @inheritdoc ISilo
    function previewMint(uint256 _shares, AssetType _assetType) external view virtual returns (uint256 assets) {
        return _previewMint(_shares, _assetType);
    }

    /// @inheritdoc ISilo
    function mint(uint256 _shares, address _receiver, AssetType _assetType)
        external
        virtual
        returns (uint256 assets)
    {
        (assets,) = _deposit(0 /* assets */, _shares, _receiver, _assetType);
    }

    /// @inheritdoc ISilo
    function maxWithdraw(address _owner, AssetType _assetType) external view virtual returns (uint256 maxAssets) {
        if (_assetType == AssetType.Debt) revert ISilo.WrongAssetType();

        (maxAssets,) = _callMaxWithdraw(config, _owner, _assetType);
    }

    /// @inheritdoc ISilo
    function previewWithdraw(uint256 _assets, AssetType _assetType) external view virtual returns (uint256 shares) {
        return _previewWithdraw(_assets, _assetType);
    }

    /// @inheritdoc ISilo
    function withdraw(uint256 _assets, address _receiver, address _owner, AssetType _assetType)
        external
        virtual
        returns (uint256 shares)
    {
        (, shares) = _withdraw(WithdrawParams(_assets, 0 /* shares */, _receiver, _owner, msg.sender, _assetType));
    }

    /// @inheritdoc ISilo
    function maxRedeem(address _owner, AssetType _assetType) external view virtual returns (uint256 maxShares) {
        if (_assetType == AssetType.Debt) revert ISilo.WrongAssetType();

        (, maxShares) = _callMaxWithdraw(config, _owner, _assetType);
    }

    /// @inheritdoc ISilo
    function previewRedeem(uint256 _shares, AssetType _assetType) external view virtual returns (uint256 assets) {
        return _previewRedeem(_shares, _assetType);
    }

    /// @inheritdoc ISilo
    function redeem(uint256 _shares, address _receiver, address _owner, AssetType _assetType)
        external
        virtual
        returns (uint256 assets)
    {
        (assets,) = _withdraw(WithdrawParams(0 /* assets */, _shares, _receiver, _owner, msg.sender, _assetType));
    }

    /// @inheritdoc ISilo
    function transitionCollateral( // solhint-disable-line function-max-lines
        uint256 _shares,
        address _owner,
        AssetType _withdrawType
    )
        external
        virtual
        returns (uint256 assets)
    {
        if (_withdrawType == AssetType.Debt) revert ISilo.WrongAssetType();

        ISiloConfig siloConfigCached = config;
        IHookReceiver hookReceiverAfter;
        ISiloConfig.ConfigData memory configData;

        (
            configData,,, hookReceiverAfter
        ) = siloConfigCached.startAction(
            address(this),
            address(0) /* no borrower */,
            Hook.BEFORE | Hook.TRANSITION_COLLATERAL,
            abi.encodePacked(_shares, _owner, _withdrawType)
        );

        _callAccrueInterestForAsset(
            configData.interestRateModel, configData.daoFee, configData.deployerFee, address(0)
        );

        { // Stack too deep
            (address shareTokenFrom, uint256 liquidity) = _withdrawType == AssetType.Collateral
                ? (configData.collateralShareToken, _getRawLiquidity())
                : (configData.protectedShareToken, total[AssetType.Protected].assets);

            (assets, _shares) = SiloERC4626Lib.transitionCollateralWithdraw(
                shareTokenFrom,
                _shares,
                _owner,
                msg.sender,
                _withdrawType,
                liquidity,
                total[_withdrawType]
            );
        }

        { // too deep
            uint256 toShares;

            (AssetType depositType, address shareTokenTo) = _withdrawType == AssetType.Collateral
                ? (AssetType.Protected, configData.protectedShareToken)
                : (AssetType.Collateral, configData.collateralShareToken);

            (assets, toShares) = SiloERC4626Lib.deposit(
                address(0), // empty token because we don't want to transfer
                _owner,
                assets,
                0, // shares
                _owner,
                IShareToken(shareTokenTo),
                total[depositType]
            );

            if (_withdrawType == AssetType.Collateral) {
                emit Withdraw(msg.sender, _owner, _owner, assets, _shares);
                emit DepositProtected(msg.sender, _owner, assets, toShares);
            } else {
                emit WithdrawProtected(msg.sender, _owner, _owner, assets, _shares);
                emit Deposit(msg.sender, _owner, assets, toShares);
            }
        }

        siloConfigCached.finishAction(
            hookReceiverAfter,
            Hook.AFTER | Hook.TRANSITION_COLLATERAL,
            abi.encodePacked(_shares, _owner, _withdrawType, assets)
        );
    }

    /// @inheritdoc ISilo
    function maxBorrow(address _borrower, bool _sameAsset) external view virtual returns (uint256 maxAssets) {
        (maxAssets,) = _callMaxBorrow(_borrower, _sameAsset);
    }

    /// @inheritdoc ISilo
    function previewBorrow(uint256 _assets) external view virtual returns (uint256 shares) {
        (uint256 totalSiloAssets, uint256 totalShares) = _getTotalAssetsAndTotalSharesWithInterest(AssetType.Debt);

        return SiloMathLib.convertToShares(
            _assets, totalSiloAssets, totalShares, Rounding.BORROW_TO_SHARES, AssetType.Debt
        );
    }

    function switchCollateralTo(bool _sameAsset) external virtual {
        ISiloConfig siloConfigCached = config;

        (
            ISiloConfig.ConfigData memory collateral,
            ISiloConfig.ConfigData memory debt,
            ISiloConfig.DebtInfo memory debtInfo,
            IHookReceiver hookReceiverAfter
        ) = siloConfigCached.startAction(
            address(this),
            msg.sender,
            Hook.BEFORE | Hook.SWITCH_COLLATERAL | (_sameAsset ? Hook.SAME_ASSET : Hook.TWO_ASSETS),
            bytes("")
        );

        emit CollateralTypeChanged(msg.sender, _sameAsset);

        _callAccrueInterestForAsset(
            collateral.interestRateModel,
            collateral.daoFee,
            collateral.deployerFee,
            collateral.otherSilo
        );

        if (!SiloSolvencyLib.isSolvent(collateral, debt, debtInfo, msg.sender, AccrueInterestInMemory.No)) {
            revert NotSolvent();
        }

        siloConfigCached.finishAction(
            hookReceiverAfter,
            Hook.AFTER | Hook.SWITCH_COLLATERAL | (_sameAsset ? Hook.SAME_ASSET : Hook.TWO_ASSETS),
            bytes("")
        );
    }

    /// @inheritdoc ISilo
    // solhint-disable-next-line code-complexity, function-max-lines
    function leverageSameAsset(uint256 _depositAssets, uint256 _borrowAssets, address _borrower, AssetType _assetType)
        external
        virtual
        returns (uint256 depositedShares, uint256 borrowedShares)
    {
        if (_depositAssets == 0 || _borrowAssets == 0) revert ISilo.ZeroAssets();

        ISiloConfig siloConfigCached = config;
        IHookReceiver hookReceiverAfter;

        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;

        { // too deep
            ISiloConfig.DebtInfo memory debtInfo;

            (
                collateralConfig,
                debtConfig,
                debtInfo,
                hookReceiverAfter
            ) = siloConfigCached.startAction(
                address(this),
                _borrower,
                Hook.BORROW | Hook.LEVERAGE | Hook.BEFORE | Hook.SAME_ASSET,
                abi.encodePacked(_depositAssets, _borrowAssets, _borrower, _assetType)
            );

            if (!SiloLendingLib.borrowPossible(debtInfo)) revert ISilo.BorrowNotPossible();
            if (debtInfo.debtPresent && !debtInfo.sameAsset) revert ISilo.TwoAssetsDebt();
        }

        _callAccrueInterestForAsset(
            collateralConfig.interestRateModel,
            collateralConfig.daoFee,
            collateralConfig.deployerFee,
            address(0) // no need to accrue for other silo
        );

        { // too deep
            (_borrowAssets, borrowedShares) = _callBorrow(
                debtConfig.debtShareToken,
                address(0), // we do not transferring debt
                _borrowAssets,
                0 /* _shares */,
                _borrower,
                _borrower,
                msg.sender
            );

            uint256 requiredCollateral = _borrowAssets * SiloLendingLib._PRECISION_DECIMALS;
            uint256 transferDiff;

            unchecked { requiredCollateral = requiredCollateral / collateralConfig.maxLtv; }
            if (_depositAssets < requiredCollateral) revert ISilo.LeverageTooHigh();

            unchecked {
                // safe because `requiredCollateral` > `_depositAssets`
                // and `_borrowAssets` is chunk of `requiredCollateral`
                transferDiff = _depositAssets - _borrowAssets;
            }

            IERC20Upgradeable(collateralConfig.token).safeTransferFrom(msg.sender, address(this), transferDiff);
        }

        (, depositedShares) = SiloERC4626Lib.deposit(
            address(0), // we do not transferring token
            msg.sender,
            _depositAssets,
            0 /* _shares */,
            _borrower,
            _assetType == AssetType.Collateral
                ? IShareToken(collateralConfig.collateralShareToken)
                : IShareToken(collateralConfig.protectedShareToken),
            total[_assetType]
        );

        siloConfigCached.finishAction(
            hookReceiverAfter,
            Hook.BORROW | Hook.LEVERAGE | Hook.AFTER | Hook.SAME_ASSET,
            abi.encodePacked(_depositAssets, _borrowAssets, _borrower, _assetType, depositedShares, borrowedShares)
        );
    }

    /// @inheritdoc ISilo
    function borrow(uint256 _assets, address _receiver, address _borrower, bool _sameAsset)
        external
        virtual
        returns (uint256 shares)
    {
        (
            , shares
        ) = _borrow(
            BorrowParams(_assets, 0 /* shares */, _receiver, _borrower, _sameAsset, false /* _leverage */),
            "" /* data */
        );
    }

    /// @inheritdoc ISilo
    function maxBorrowShares(address _borrower, bool _sameAsset) external view virtual returns (uint256 maxShares) {
        (,maxShares) = _callMaxBorrow(_borrower, _sameAsset);
    }

    /// @inheritdoc ISilo
    function previewBorrowShares(uint256 _shares) external view virtual returns (uint256 assets) {
        (uint256 totalSiloAssets, uint256 totalShares) = _getTotalAssetsAndTotalSharesWithInterest(AssetType.Debt);

        return SiloMathLib.convertToAssets(
            _shares, totalSiloAssets, totalShares, Rounding.BORROW_TO_ASSETS, AssetType.Debt
        );
    }

    /// @inheritdoc ISilo
    function borrowShares(uint256 _shares, address _receiver, address _borrower, bool _sameAsset)
        external
        virtual
        returns (uint256 assets)
    {
        (
            assets,
        ) = _borrow(
            BorrowParams(0 /* assets */, _shares, _receiver, _borrower, _sameAsset, false /* _leverage */),
            "" /* data */
        );
    }

    /// @inheritdoc ISilo
    function maxRepay(address _borrower) external view virtual returns (uint256 assets) {
        ISiloConfig.ConfigData memory configData = config.getConfig(address(this));
        uint256 shares = IShareToken(configData.debtShareToken).balanceOf(_borrower);

        (uint256 totalSiloAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(configData, AssetType.Debt);

        return SiloMathLib.convertToAssets(
            shares, totalSiloAssets, totalShares, Rounding.MAX_REPAY_TO_ASSETS, AssetType.Debt
        );
    }

    /// @inheritdoc ISilo
    function previewRepay(uint256 _assets) external view virtual returns (uint256 shares) {
        (uint256 totalSiloAssets, uint256 totalShares) = _getTotalAssetsAndTotalSharesWithInterest(AssetType.Debt);

        return SiloMathLib.convertToShares(
            _assets, totalSiloAssets, totalShares, Rounding.REPAY_TO_SHARES, AssetType.Debt
        );
    }

    /// @inheritdoc ISilo
    function repay(uint256 _assets, address _borrower)
        external
        virtual
        returns (uint256 shares)
    {
        (, shares) = _repay(_assets, 0 /* repaySharesZero */, _borrower, msg.sender, false /* _liquidation */);
    }

    /// @inheritdoc ILiquidationProcess
    function liquidationRepay(uint256 _assets, address _borrower, address _repayer)
        external
        virtual
        returns (uint256 shares)
    {
        (, shares) = _repay(_assets, 0 /* repaySharesZero */, _borrower, _repayer, true /* _liquidation */);
    }

    /// @inheritdoc ISilo
    function maxRepayShares(address _borrower) external view virtual returns (uint256 shares) {
        ISiloConfig.ConfigData memory configData = config.getConfig(address(this));
        shares = IShareToken(configData.debtShareToken).balanceOf(_borrower);
    }

    /// @inheritdoc ISilo
    function previewRepayShares(uint256 _shares) external view virtual returns (uint256 assets) {
        (uint256 totalSiloAssets, uint256 totalShares) = _getTotalAssetsAndTotalSharesWithInterest(AssetType.Debt);

        return SiloMathLib.convertToAssets(
            _shares, totalSiloAssets, totalShares, Rounding.REPAY_TO_ASSETS, AssetType.Debt
        );
    }

    /// @inheritdoc ISilo
    function repayShares(uint256 _shares, address _borrower)
        external
        virtual
        returns (uint256 assets)
    {
        (assets,) = _repay(0 /* zeroAssets */, _shares, _borrower, msg.sender, false /* _liquidation */);
    }

    /// @inheritdoc IERC3156FlashLender
    function maxFlashLoan(address _token) external view virtual returns (uint256 maxLoan) {
        maxLoan =
            _token == config.getAssetForSilo(address(this)) ? IERC20Upgradeable(_token).balanceOf(address(this)) : 0;
    }

    /// @inheritdoc IERC3156FlashLender
    function flashFee(address _token, uint256 _amount) external view virtual returns (uint256 fee) {
        fee = SiloStdLib.flashFee(config, _token, _amount);
    }

    /// @inheritdoc IERC3156FlashLender
    function flashLoan(IERC3156FlashBorrower _receiver, address _token, uint256 _amount, bytes calldata _data)
        external
        virtual
        returns (bool success)
    {
        return SiloLendingLib.flashLoan(config, siloData, _receiver, _token, _amount, _data);
    }

    /// @inheritdoc ISilo
    function leverage(
        uint256 _assets,
        ILeverageBorrower _receiver,
        address _borrower,
        bool _sameAsset,
        bytes calldata _data
    )
        external
        virtual
        returns (uint256 shares)
    {
        (
            , shares
        ) = _borrow(BorrowParams(_assets, 0 /* _shares */, address(_receiver), _borrower, _sameAsset, true), _data);
    }

    /// @inheritdoc ISilo
    function accrueInterest() external virtual returns (uint256 accruedInterest) {
        ISiloConfig.ConfigData memory configData = config.getConfig(address(this));

        accruedInterest = _callAccrueInterestForAsset(
            configData.interestRateModel, configData.daoFee, configData.deployerFee, configData.otherSilo
        );
    }

    /// @inheritdoc ISilo
    function withdrawFees() external virtual {
        SiloStdLib.withdrawFees(this, siloData);
    }

    /// @dev that method allow to finish liquidation process by giving up collateral to liquidator
    function withdrawCollateralsToLiquidator(
        uint256 _withdrawAssetsFromCollateral,
        uint256 _withdrawAssetsFromProtected,
        address _borrower,
        address _liquidator,
        bool _receiveSToken
    ) external virtual {
        LiquidationWithdrawLib.withdrawCollateralsToLiquidator(
            config,
            _withdrawAssetsFromCollateral,
            _withdrawAssetsFromProtected,
            _borrower,
            _liquidator,
            _receiveSToken,
            _getRawLiquidity(),
            total
        );
    }

    function _getRawLiquidity() internal view virtual returns (uint256 liquidity) {
        liquidity = SiloMathLib.liquidity(total[AssetType.Collateral].assets, total[AssetType.Debt].assets);
    }

    function _deposit(
        uint256 _assets,
        uint256 _shares,
        address _receiver,
        ISilo.AssetType _assetType
    )
        internal
        virtual
        returns (uint256 assets, uint256 shares)
    {
        if (_assetType == AssetType.Debt) revert ISilo.WrongAssetType();

        ISiloConfig siloConfigCached = config;

        (
            ISiloConfig.ConfigData memory collateralConfig,,,
            IHookReceiver hookReceiverAfter
        ) = siloConfigCached.startAction(
            address(this),
            address(0),
            Hook.DEPOSIT | Hook.BEFORE,
            abi.encodePacked(_assets, _shares, _receiver, _assetType)
        );

        _callAccrueInterestForAsset(
            collateralConfig.interestRateModel, collateralConfig.daoFee, collateralConfig.deployerFee, address(0)
        );

        address collateralShareToken = _assetType == AssetType.Collateral
            ? collateralConfig.collateralShareToken
            : collateralConfig.protectedShareToken;

        (assets, shares) = SiloERC4626Lib.deposit(
            collateralConfig.token,
            msg.sender,
            _assets,
            _shares,
            _receiver,
            IShareToken(collateralShareToken),
            total[_assetType]
        );

        if (_assetType == AssetType.Collateral) {
            emit Deposit(msg.sender, _receiver, assets, shares);
        } else {
            emit DepositProtected(msg.sender, _receiver, assets, shares);
        }

        siloConfigCached.finishAction(
            hookReceiverAfter,
            Hook.DEPOSIT | Hook.AFTER,
            abi.encodePacked(_assets, _shares, _receiver, _assetType, assets, shares)
        );
    }

    // solhint-disable-next-line function-max-lines, code-complexity
    function _withdraw(WithdrawParams memory _params)
        internal
        virtual
        returns (uint256 assets, uint256 shares)
    {
        if (_params.assetType == AssetType.Debt) revert ISilo.WrongAssetType();

        ISiloConfig siloConfigCached = config;

        (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig,
            ISiloConfig.DebtInfo memory debtInfo,
            IHookReceiver hookReceiverAfter
        ) = siloConfigCached.startAction(
            address(this),
            _params.owner,
            Hook.WITHDRAW | Hook.BEFORE,
            abi.encode(_params)
        );

        _callAccrueInterestForAsset(
            collateralConfig.interestRateModel,
            collateralConfig.daoFee,
            collateralConfig.deployerFee,
            collateralConfig.otherSilo
        );

        // this if helped with Stack too deep
        if (_params.assetType == AssetType.Collateral) {
            (assets, shares) = _callWithdraw(
                collateralConfig.token,
                collateralConfig.collateralShareToken,
                _params.assets,
                _params.shares,
                _params.receiver,
                _params.owner,
                _params.spender,
                _params.assetType,
                _getRawLiquidity(),
                total[AssetType.Collateral]
            );
        } else {
            (assets, shares) = _callWithdraw(
                collateralConfig.token,
                collateralConfig.protectedShareToken,
                _params.assets,
                _params.shares,
                _params.receiver,
                _params.owner,
                _params.spender,
                _params.assetType,
                total[AssetType.Protected].assets,
                total[AssetType.Protected]
            );
        }

        if (_params.assetType == AssetType.Collateral) {
            emit Withdraw(msg.sender, _params.receiver, _params.owner, assets, shares);
        } else {
            emit WithdrawProtected(msg.sender, _params.receiver, _params.owner, assets, shares);
        }

        if (SiloSolvencyLib.depositWithoutDebt(debtInfo)) {
            siloConfigCached.finishAction(
                hookReceiverAfter,
                Hook.WITHDRAW | Hook.AFTER,
                abi.encode(_params, assets, shares)
            );

            return (assets, shares);
        }

        if (collateralConfig.callBeforeQuote) {
            ISiloOracle(collateralConfig.solvencyOracle).beforeQuote(collateralConfig.token);
        }

        if (debtConfig.callBeforeQuote) {
            ISiloOracle(debtConfig.solvencyOracle).beforeQuote(debtConfig.token);
        }

        // `_params.owner` must be solvent
        if (!SiloSolvencyLib.isSolvent(
            collateralConfig, debtConfig, debtInfo, _params.owner, AccrueInterestInMemory.No
        )) {
            revert NotSolvent();
        }

        siloConfigCached.finishAction(
            hookReceiverAfter,
            Hook.WITHDRAW | Hook.AFTER,
            abi.encode(_params, assets, shares)
        );
    }

    function _borrow( // solhint-disable-line function-max-lines, code-complexity
        BorrowParams memory _params,
        bytes memory _data
    )
        internal
        virtual
        returns (uint256 assets, uint256 shares)
    {
        if (_params.assets == 0 && _params.shares == 0) revert ISilo.ZeroAssets();

        ISiloConfig siloConfigCached = config;
        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;
        IHookReceiver hookReceiverAfter;

        { // too deep
            ISiloConfig.DebtInfo memory debtInfo;

            (
                collateralConfig, debtConfig, debtInfo, hookReceiverAfter
            ) = siloConfigCached.startAction(
                address(this),
                _params.borrower,
                Hook.BORROW | Hook.BEFORE | (_params.sameAsset ? Hook.SAME_ASSET : Hook.TWO_ASSETS),
                abi.encode(_params)
            );

            if (!SiloLendingLib.borrowPossible(debtInfo)) revert ISilo.BorrowNotPossible();
        }

        // TODO optimisation, use collateralConfig.silo instead of debtConfig.otherSilo
        _callAccrueInterestForAsset(
            debtConfig.interestRateModel, debtConfig.daoFee, debtConfig.deployerFee, debtConfig.otherSilo
        );

        (assets, shares) = _callBorrow(
            debtConfig.debtShareToken,
            debtConfig.token,
            _params.assets,
            _params.shares,
            _params.receiver,
            _params.borrower,
            msg.sender
        );

        // balanceOf shares
        emit Borrow(msg.sender, _params.receiver, _params.borrower, assets, shares);

        if (_params.leverage) {
            // change reentrant flag to leverage, to allow for deposit
            siloConfigCached.crossLeverageGuard(CrossEntrancy.ENTERED_FROM_LEVERAGE);

            emit Leverage();

            bytes32 result = ILeverageBorrower(_params.receiver)
                .onLeverage(msg.sender, _params.borrower, debtConfig.token, assets, _data);

            // allow for deposit reentry only to provide collateral
            if (result != _LEVERAGE_CALLBACK) revert LeverageFailed();

            // after deposit, guard is down, for max security we need to enable it again
            siloConfigCached.crossLeverageGuard(CrossEntrancy.ENTERED);
        }

        if (collateralConfig.callBeforeQuote) {
            ISiloOracle(collateralConfig.maxLtvOracle).beforeQuote(collateralConfig.token);
        }

        if (debtConfig.callBeforeQuote) {
            ISiloOracle(debtConfig.maxLtvOracle).beforeQuote(debtConfig.token);
        }

        if (!SiloSolvencyLib.isBelowMaxLtv(collateralConfig, debtConfig, _params.borrower, AccrueInterestInMemory.No)) {
            revert AboveMaxLtv();
        }

        siloConfigCached.finishAction(
            hookReceiverAfter,
            Hook.BORROW | Hook.AFTER,
            abi.encode(_params, assets, shares)
        );
    }

    /// @param _liquidation TRUE when call is from liquidator module
    function _repay(uint256 _assets, uint256 _shares, address _borrower, address _repayer, bool _liquidation)
        internal
        virtual
        returns (uint256 assets, uint256 shares)
    {
        ISiloConfig siloConfigCached = config;
        (,ISiloConfig.ConfigData memory debtConfig,, IHookReceiver hookReceiverAfter) = siloConfigCached.startAction(
            address(this),
            _borrower,
            Hook.REPAY | Hook.BEFORE | (_liquidation ? Hook.LIQUIDATION : 0),
            abi.encodePacked(_assets, _shares, _borrower, _repayer)
        );

        _callAccrueInterestForAsset(
            debtConfig.interestRateModel, debtConfig.daoFee, debtConfig.deployerFee, address(0)
        );

        if (_liquidation && debtConfig.liquidationModule != msg.sender) revert ISilo.OnlyLiquidationModule();

        (
            assets, shares
        ) = SiloLendingLib.repay(debtConfig, _assets, _shares, _borrower, _repayer, total[AssetType.Debt]);

        emit Repay(_repayer, _borrower, assets, shares);

        if (!_liquidation) {
            siloConfigCached.finishAction(
                hookReceiverAfter,
                Hook.REPAY | Hook.AFTER | (_liquidation ? Hook.LIQUIDATION : 0),
                abi.encodePacked(_assets, _shares, _borrower, _repayer, assets, shares)
            );
        }
    }

    function _getTotalAssetsAndTotalSharesWithInterest(AssetType _assetType)
        internal
        view
        returns (uint256 assets, uint256 shares)
    {
        ISiloConfig.ConfigData memory configData = config.getConfig(address(this));
        (assets, shares) = SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(configData, _assetType);
    }

    function _getShareToken() internal view virtual override returns (address collateralShareToken) {
        (, collateralShareToken,) = config.getShareTokens(address(this));
    }

    function _previewMint(uint256 _shares, AssetType _assetType) internal view virtual returns (uint256 assets) {
        if (_assetType == AssetType.Debt) revert ISilo.WrongAssetType();

        (uint256 totalSiloAssets, uint256 totalShares) = _getTotalAssetsAndTotalSharesWithInterest(_assetType);

        return SiloMathLib.convertToAssets(
            _shares, totalSiloAssets, totalShares, Rounding.DEPOSIT_TO_ASSETS, _assetType
        );
    }

    function _previewDeposit(uint256 _assets, AssetType _assetType) internal view virtual returns (uint256 shares) {
        if (_assetType == AssetType.Debt) revert ISilo.WrongAssetType();

        (uint256 totalSiloAssets, uint256 totalShares) = _getTotalAssetsAndTotalSharesWithInterest(_assetType);

        return SiloMathLib.convertToShares(
            _assets, totalSiloAssets, totalShares, Rounding.DEPOSIT_TO_SHARES, _assetType
        );
    }

    function _previewRedeem(
        uint256 _shares,
        ISilo.AssetType _assetType
    ) internal view virtual returns (uint256 assets) {
        if (_assetType == ISilo.AssetType.Debt) revert ISilo.WrongAssetType();

        (uint256 totalSiloAssets, uint256 totalShares) = _getTotalAssetsAndTotalSharesWithInterest(_assetType);

        return SiloMathLib.convertToAssets(
            _shares, totalSiloAssets, totalShares, Rounding.WITHDRAW_TO_ASSETS, _assetType
        );
    }

    function _previewWithdraw(
        uint256 _assets,
        ISilo.AssetType _assetType
    ) internal view virtual returns (uint256 shares) {
        if (_assetType == ISilo.AssetType.Debt) revert ISilo.WrongAssetType();

        (uint256 totalSiloAssets, uint256 totalShares) = _getTotalAssetsAndTotalSharesWithInterest(_assetType);

        return SiloMathLib.convertToShares(
            _assets, totalSiloAssets, totalShares, Rounding.WITHDRAW_TO_SHARES, _assetType
        );
    }

    function _callMaxBorrow(address _borrower, bool _sameAsset)
        internal
        view
        virtual
        returns (uint256 maxAssets, uint256 maxShares)
    {
        ISiloConfig siloConfigCached = config;

        (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig,
            ISiloConfig.DebtInfo memory debtInfo
        ) = siloConfigCached.getConfigs(
            address(this),
            _borrower,
            Hook.BORROW | (_sameAsset ? Hook.SAME_ASSET : Hook.TWO_ASSETS)
        );

        if (!SiloLendingLib.borrowPossible(debtInfo)) return (0, 0);

        if (_sameAsset) {
            collateralConfig = debtConfig;
        }

        (uint256 totalDebtAssets, uint256 totalDebtShares) =
            SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(debtConfig, AssetType.Debt);

        return SiloLendingLib.maxBorrow(
            collateralConfig,
            debtConfig,
            _borrower,
            totalDebtAssets,
            totalDebtShares,
            siloConfigCached
        );
    }

    function _callMaxDepositOrMint(uint256 _totalCollateralAssets)
        internal
        view
        virtual
        returns (uint256 maxAssetsOrShares)
    {
        return SiloERC4626Lib.maxDepositOrMint(_totalCollateralAssets);
    }

    function _callMaxWithdraw(ISiloConfig _config, address _owner, ISilo.AssetType _assetType)
        internal
        view
        virtual
        returns (uint256 assets, uint256 shares)
    {
        return SiloERC4626Lib.maxWithdraw(
            _config,
            _owner,
            _assetType,
            _assetType == AssetType.Protected ? total[AssetType.Protected].assets : 0 // will be calculated internally
        );
    }

    function _callAccrueInterestForAsset(
        address _interestRateModel,
        uint256 _daoFee,
        uint256 _deployerFee,
        address _otherSilo
    ) internal virtual returns (uint256 accruedInterest) {
        if (_otherSilo != address(0) && _otherSilo != address(this)) {
            ISilo(_otherSilo).accrueInterest();
        }

        return SiloLendingLib.accrueInterestForAsset(
            _interestRateModel,
            _daoFee,
            _deployerFee,
            siloData,
            total[AssetType.Collateral],
            total[AssetType.Debt]
        );
    }

    function _callWithdraw(
        address _asset,
        address _shareToken,
        uint256 _assets,
        uint256 _shares,
        address _receiver,
        address _owner,
        address _spender,
        ISilo.AssetType _assetType,
        uint256 _liquidity,
        ISilo.Assets storage _totalCollateral
    ) internal virtual returns (uint256 assets, uint256 shares) {
        return SiloERC4626Lib.withdraw(
            _asset,
            _shareToken,
            _assets,
            _shares,
            _receiver,
            _owner,
            _spender,
            _assetType,
            _liquidity,
            _totalCollateral
        );
    }

    function _callBorrow(
        address _debtShareToken,
        address _token,
        uint256 _assets,
        uint256 _shares,
        address _receiver,
        address _borrower,
        address _spender
    ) internal returns (uint256 borrowedAssets, uint256 borrowedShares) {
        return SiloLendingLib.borrow(
            _debtShareToken,
            _token,
            _assets,
            _shares,
            _receiver,
            _borrower,
            _spender,
            total[AssetType.Debt],
            total[AssetType.Collateral].assets
        );
    }
}
