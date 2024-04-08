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

import {XReentrancyGuard} from "./utils/XReentrancyGuard.sol";
import {SiloERC4626} from "./utils/SiloERC4626.sol";
import {SiloStdLib} from "./lib/SiloStdLib.sol";
import {SiloSolvencyLib} from "./lib/SiloSolvencyLib.sol";
import {SiloLendingLib} from "./lib/SiloLendingLib.sol";
import {SiloERC4626Lib} from "./lib/SiloERC4626Lib.sol";
import {SiloMathLib} from "./lib/SiloMathLib.sol";
import {LiquidationWithdrawLib} from "./lib/LiquidationWithdrawLib.sol";
import {Rounding} from "./lib/Rounding.sol";
import {Methods} from "./lib/Methods.sol";

// Keep ERC4626 ordering
// solhint-disable ordering

/// @title Silo vault with lending and borrowing functionality
/// @notice Silo is a ERC4626-compatible vault that allows users to deposit collateral and borrow debt. This contract
/// is deployed twice for each asset for two-asset lending markets.
/// Version: 2.0.0
contract Silo is Initializable, SiloERC4626, XReentrancyGuard {
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
        ) = config.getConfigs(address(this), _borrower, Methods.IS_SOLVENT);

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
        xNonReentrant(config)
        returns (uint256 shares)
    {
        if (_assets == 0) revert ISilo.ZeroAssets();

        (, ISiloConfig.ConfigData memory configData) = _accrueInterest();

        (, shares) = _deposit(
            configData.token,
            _assets,
            0, // shares
            _receiver,
            AssetType.Collateral,
            IShareToken(configData.collateralShareToken)
        );
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
    function mint(uint256 _shares, address _receiver)
        external
        virtual
        xNonReentrant(config)
        returns (uint256 assets)
    {
        (, ISiloConfig.ConfigData memory configData) = _accrueInterest();

        (assets,) = _deposit(
            configData.token,
            0, // assets
            _shares,
            _receiver,
            AssetType.Collateral,
            IShareToken(configData.collateralShareToken)
        );
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
        xNonReentrant(config)
        returns (uint256 shares)
    {
        (, shares) = _withdraw(_assets, 0 /* shares */, _receiver, _owner, msg.sender, AssetType.Collateral);
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
        xNonReentrant(config)
        returns (uint256 assets)
    {
        // avoid magic number 0
        uint256 zeroAssets = 0;

        (assets,) = _withdraw(zeroAssets, _shares, _receiver, _owner, msg.sender, AssetType.Collateral);
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
        xNonReentrant(config)
        returns (uint256 shares)
    {
        if (_assets == 0) revert ISilo.ZeroAssets();

        (, ISiloConfig.ConfigData memory configData) = _accrueInterest();

        address collateralShareToken = _assetType == AssetType.Collateral
            ? configData.collateralShareToken
            : configData.protectedShareToken;

        (, shares) = _deposit(
            configData.token,
            _assets,
            0, // shares
            _receiver,
            _assetType,
            IShareToken(collateralShareToken)
        );
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
        xNonReentrant(config)
        returns (uint256 assets)
    {
        if (_shares == 0) revert ISilo.ZeroShares();

        (, ISiloConfig.ConfigData memory configData) = _accrueInterest();

        address collateralShareToken = _assetType == AssetType.Collateral
            ? configData.collateralShareToken
            : configData.protectedShareToken;

        (assets,) = _deposit(
            configData.token,
            0, // asstes
            _shares,
            _receiver,
            _assetType,
            IShareToken(collateralShareToken)
        );
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
        xNonReentrant(config)
        returns (uint256 shares)
    {
        (, shares) = _withdraw(_assets, 0 /* shares */, _receiver, _owner, msg.sender, _assetType);
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
        xNonReentrant(config)
        returns (uint256 assets)
    {
        (assets,) = _withdraw(0 /* assets */, _shares, _receiver, _owner, msg.sender, _assetType);
    }

    /// @inheritdoc ISilo
    function transitionCollateral( // solhint-disable-line function-max-lines
        uint256 _shares,
        address _owner,
        AssetType _withdrawType
    )
        external
        virtual
        xNonReentrant(config)
        returns (uint256 assets)
    {
        if (_withdrawType == AssetType.Debt) revert ISilo.WrongAssetType();

        (, ISiloConfig.ConfigData memory configData) = _accrueInterest();

        uint256 toShares;

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

    function switchCollateralTo(bool _sameAsset) external virtual xNonReentrant(config) {
        ISiloConfig cacheConfig = config;

        (
            ISiloConfig.ConfigData memory collateral,
            ISiloConfig.ConfigData memory debt,
            ISiloConfig.DebtInfo memory debtInfo
        ) = cacheConfig.changeCollateralType(msg.sender, _sameAsset);

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
    }

    /// @inheritdoc ISilo
    // solhint-disable-next-line code-complexity, function-max-lines
    function leverageSameAsset(uint256 _depositAssets, uint256 _borrowAssets, address _borrower, AssetType _assetType)
        external
        virtual
        xNonReentrant(config)
        returns (uint256 depositedShares, uint256 borrowedShares)
    {
        if (_depositAssets == 0 || _borrowAssets == 0) revert ISilo.ZeroAssets();

        (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig,
            ISiloConfig.DebtInfo memory debtInfo
        ) = config.getConfigs(address(this), _borrower, Methods.BORROW_SAME_ASSET);

        if (!SiloLendingLib.borrowPossible(debtInfo)) revert ISilo.BorrowNotPossible();
        if (debtInfo.debtPresent && !debtInfo.sameAsset) revert ISilo.TwoAssetsDebt();

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
    }

    /// @inheritdoc ISilo
    function borrow(uint256 _assets, address _receiver, address _borrower, bool _sameAsset)
        external
        virtual
        xNonReentrant(config)
        returns (uint256 shares)
    {
        (
            , shares
        ) = _borrow(_assets, 0 /* shares */, _receiver, _borrower, _sameAsset, false /* _leverage */, "" /* data */);
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
        xNonReentrant(config)
        returns (uint256 assets)
    {
        (
            assets,
        ) = _borrow(0 /* assets */, _shares, _receiver, _borrower, _sameAsset, false /* _leverage */, "" /* data */);
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
        xNonReentrant(config)
        returns (uint256 shares)
    {
        // avoid magic number 0
        uint256 repaySharesZero = 0;

        (, shares) = _repay(_assets, repaySharesZero, _borrower, msg.sender, false /* _liquidation */);
    }

    /// @inheritdoc ILiquidationProcess
    function liquidationRepay(uint256 _assets, address _borrower, address _repayer)
        external
        virtual
        xNonReentrant(config)
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
        xNonReentrant(config)
        returns (uint256 assets)
    {
        // avoid magic number 0
        uint256 zeroAssets = 0;

        (assets,) = _repay(zeroAssets, _shares, _borrower, msg.sender, false /* _liquidation */);
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
        xNonReentrant(config)
        returns (uint256 shares)
    {
        (, shares) = _borrow(_assets, 0 /* _shares */, address(_receiver), _borrower, _sameAsset, true, _data);
    }

    /// @inheritdoc ISilo
    function accrueInterest() external virtual returns (uint256 accruedInterest) {
        (accruedInterest,) = _accrueInterest();
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

    function _accrueInterest()
        internal
        virtual
        returns (uint256 accruedInterest, ISiloConfig.ConfigData memory configData)
    {
        configData = config.getConfig(address(this));

        accruedInterest = _callAccrueInterestForAsset(
            configData.interestRateModel, configData.daoFee, configData.deployerFee, address(0)
        );
    }

    function _getRawLiquidity() internal view virtual returns (uint256 liquidity) {
        liquidity = SiloMathLib.liquidity(total[AssetType.Collateral].assets, total[AssetType.Debt].assets);
    }

    function _deposit(
        address _token,
        uint256 _assets,
        uint256 _shares,
        address _receiver,
        ISilo.AssetType _assetType,
        IShareToken _collateralShareToken
    )
        internal
        virtual
        returns (uint256 assets, uint256 shares)
    {
        if (_assetType == AssetType.Debt) revert ISilo.WrongAssetType();

        (assets, shares) = SiloERC4626Lib.deposit(
            _token,
            msg.sender,
            _assets,
            _shares,
            _receiver,
            _collateralShareToken,
            total[_assetType]
        );

        if (_assetType == AssetType.Collateral) {
            emit Deposit(msg.sender, _receiver, assets, shares);
        } else {
            emit DepositProtected(msg.sender, _receiver, assets, shares);
        }
    }

    // solhint-disable-next-line function-max-lines, code-complexity
    function _withdraw(
        uint256 _assets,
        uint256 _shares,
        address _receiver,
        address _owner,
        address _spender,
        ISilo.AssetType _assetType
    )
        internal
        virtual
        returns (uint256 assets, uint256 shares)
    {
        if (_assetType == AssetType.Debt) revert ISilo.WrongAssetType();

        (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig,
            ISiloConfig.DebtInfo memory debtInfo
        ) = config.getConfigs(address(this), _owner, Methods.WITHDRAW);

        _callAccrueInterestForAsset(
            collateralConfig.interestRateModel,
            collateralConfig.daoFee,
            collateralConfig.deployerFee,
            collateralConfig.otherSilo
        );

        // this if helped with Stack too deep
        if (_assetType == AssetType.Collateral) {
            (assets, shares) = _callWithdraw(
                collateralConfig.token,
                collateralConfig.collateralShareToken,
                _assets,
                _shares,
                _receiver,
                _owner,
                _spender,
                _assetType,
                _getRawLiquidity(),
                total[AssetType.Collateral]
            );
        } else {
            (assets, shares) = _callWithdraw(
                collateralConfig.token,
                collateralConfig.protectedShareToken,
                _assets,
                _shares,
                _receiver,
                _owner,
                _spender,
                _assetType,
                total[AssetType.Protected].assets,
                total[AssetType.Protected]
            );
        }

        if (_assetType == AssetType.Collateral) {
            emit Withdraw(msg.sender, _receiver, _owner, assets, shares);
        } else {
            emit WithdrawProtected(msg.sender, _receiver, _owner, assets, shares);
        }

        if (SiloSolvencyLib.depositWithoutDebt(debtInfo)) {
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
            collateralConfig, debtConfig, debtInfo, _owner, AccrueInterestInMemory.No
        )) {
            revert NotSolvent();
        }
    }

    function _borrow( // solhint-disable-line function-max-lines, code-complexity
        uint256 _assets,
        uint256 _shares,
        address _receiver,
        address _borrower,
        bool _sameAsset,
        bool _leverage,
        bytes memory _data
    )
        internal
        virtual
        returns (uint256 assets, uint256 shares)
    {
        if (_assets == 0 && _shares == 0) revert ISilo.ZeroAssets();

        (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig,
            ISiloConfig.DebtInfo memory debtInfo
        ) = config.openDebt(_borrower, _sameAsset);

        if (!SiloLendingLib.borrowPossible(debtInfo)) revert ISilo.BorrowNotPossible();

        // TODO optimisation, use collateralConfig.silo instead of debtConfig.otherSilo
        _callAccrueInterestForAsset(
            debtConfig.interestRateModel, debtConfig.daoFee, debtConfig.deployerFee, debtConfig.otherSilo
        );

        (assets, shares) = _callBorrow(
            debtConfig.debtShareToken,
            debtConfig.token,
            _assets,
            _shares,
            _receiver,
            _borrower,
            msg.sender
        );

        emit Borrow(msg.sender, _receiver, _borrower, assets, shares);

        if (_leverage) {
            emit Leverage();

            bytes32 result = ILeverageBorrower(_receiver)
                .onLeverage(msg.sender, _borrower, debtConfig.token, assets, _data);

            // allow for deposit reentry only to provide collateral
            if (result != _LEVERAGE_CALLBACK) revert LeverageFailed();
        }

        if (collateralConfig.callBeforeQuote) {
            ISiloOracle(collateralConfig.maxLtvOracle).beforeQuote(collateralConfig.token);
        }

        if (debtConfig.callBeforeQuote) {
            ISiloOracle(debtConfig.maxLtvOracle).beforeQuote(debtConfig.token);
        }

        if (!SiloSolvencyLib.isBelowMaxLtv(collateralConfig, debtConfig, _borrower, AccrueInterestInMemory.No)) {
            revert AboveMaxLtv();
        }
    }

    function _repay(uint256 _assets, uint256 _shares, address _borrower, address _repayer, bool _liquidation)
        internal
        virtual
        returns (uint256 assets, uint256 shares)
    {
        (, ISiloConfig.ConfigData memory configData) = _accrueInterest();

        if (_liquidation && configData.liquidationModule != msg.sender) revert ISilo.OnlyLiquidationModule();

        (
            assets, shares
        ) = SiloLendingLib.repay(configData, _assets, _shares, _borrower, _repayer, total[AssetType.Debt]);

        emit Repay(_repayer, _borrower, assets, shares);
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
        ISiloConfig cachedConfig = config;

        (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig,
            ISiloConfig.DebtInfo memory debtInfo
        ) = cachedConfig.getConfigs(
            address(this),
            _borrower,
            _sameAsset ? Methods.BORROW_SAME_ASSET : Methods.BORROW_TWO_ASSETS
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
            cachedConfig
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
