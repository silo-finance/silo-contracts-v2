// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

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

import {Actions} from "./lib/Actions.sol";
import {SiloStdLib} from "./lib/SiloStdLib.sol";
import {SiloSolvencyLib} from "./lib/SiloSolvencyLib.sol";
import {SiloLendingLib} from "./lib/SiloLendingLib.sol";
import {SiloERC4626Lib} from "./lib/SiloERC4626Lib.sol";
import {SiloMathLib} from "./lib/SiloMathLib.sol";
import {LiquidationWithdrawLib} from "./lib/LiquidationWithdrawLib.sol";
import {Rounding} from "./lib/Rounding.sol";
import {Hook} from "./lib/Hook.sol";

// Keep ERC4626 ordering
// solhint-disable ordering

/// @title Silo vault with lending and borrowing functionality
/// @notice Silo is a ERC4626-compatible vault that allows users to deposit collateral and borrow debt. This contract
/// is deployed twice for each asset for two-asset lending markets.
/// Version: 2.0.0
contract Silo is SiloERC4626 {
    using SafeERC20 for IERC20;

    ISiloFactory public immutable factory;
    
    SiloData public siloData;

    SharedStorage public sharedStorage;

    /// @dev silo is just for one asset, but this one asset can be of three types, so we store `assets` by type. We use
    /// struct instead of uint256 to pass storage reference to functions.
    /// `total` can have outdated value (without interest), if you doing view call (of off-chain call) please use
    /// getters eg `getCollateralAssets()` to fetch value that includes interest.
    mapping(uint8 assetType => Assets) public override total;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(ISiloFactory _siloFactory) {
        factory = _siloFactory;

        // Set the config to a non-zero value in order to prevent the implementation contract from being initialized
        sharedStorage.siloConfig = ISiloConfig(address(this));
    }

    /// @dev Silo is not designed to work with ether, but it can act as a middleware
    /// between any third-party contract and hook receiver. So, this is the responsibility
    /// of the hook receiver developer to handle it if needed.
    receive() external payable {}

    /// @inheritdoc ISilo
    function callOnBehalfOfSilo(address _target, uint256 _value, bytes calldata _input)
        external
        payable
        returns (bool success, bytes memory result)
    {
        if (msg.sender != address(sharedStorage.hookReceiver)) revert OnlyHookReceiver();

        (success, result) = _target.call{value: _value}(_input);
        // Silo will not send back any ether leftovers after the call.
        // The hook receiver should request the ether if needed in a separate call.
    }

    /// @inheritdoc ISilo
    function initialize(ISiloConfig _siloConfig, address _modelConfigAddress) external virtual {
        if (address(sharedStorage.siloConfig) != address(0)) revert SiloInitialized();

        ISiloConfig.ConfigData memory configData = _siloConfig.getConfig(address(this));

        sharedStorage.siloConfig = _siloConfig;
        sharedStorage.hookReceiver = IHookReceiver(configData.hookReceiver);

        IInterestRateModel(configData.interestRateModel).connect(_modelConfigAddress);
    }

    /// @inheritdoc ISilo
    function updateHooks() external {
        (uint24 hooksBefore, uint24 hooksAfter) = Actions.updateHooks(sharedStorage);
        emit HooksUpdated(hooksBefore, hooksAfter);
    }

    /// @inheritdoc ISilo
    function config() external view virtual returns (ISiloConfig siloConfig) {
        siloConfig = sharedStorage.siloConfig;
    }

    /// @inheritdoc ISilo
    function utilizationData() external view virtual returns (UtilizationData memory) {
        return UtilizationData({
            collateralAssets: total[uint8(AssetType.Collateral)].assets,
            debtAssets: total[uint8(AssetType.Debt)].assets,
            interestRateTimestamp: siloData.interestRateTimestamp
        });
    }

    function getLiquidity() external view virtual returns (uint256 liquidity) {
        return SiloLendingLib.getLiquidity(sharedStorage.siloConfig);
    }

    /// @inheritdoc ISilo
    function isSolvent(address _borrower) external view virtual returns (bool) {
        (
            ISiloConfig.ConfigData memory collateral,
            ISiloConfig.ConfigData memory debt,
            ISiloConfig.DebtInfo memory debtInfo
        ) = sharedStorage.siloConfig.getConfigs(address(this), _borrower, Hook.NONE);

        return SiloSolvencyLib.isSolvent(collateral, debt, debtInfo, _borrower, AccrueInterestInMemory.Yes);
    }

    /// @inheritdoc ISilo
    function getCollateralAssets() external view virtual returns (uint256 totalCollateralAssets) {
        ISiloConfig.ConfigData memory thisSiloConfig = sharedStorage.siloConfig.getConfig(address(this));

        totalCollateralAssets = SiloStdLib.getTotalCollateralAssetsWithInterest(
            thisSiloConfig.silo,
            thisSiloConfig.interestRateModel,
            thisSiloConfig.daoFee,
            thisSiloConfig.deployerFee
        );
    }

    /// @inheritdoc ISilo
    function getDebtAssets() external view virtual returns (uint256 totalDebtAssets) {
        ISiloConfig.ConfigData memory thisSiloConfig = sharedStorage.siloConfig.getConfig(address(this));

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
        totalCollateralAssets = total[uint8(AssetType.Collateral)].assets;
        totalProtectedAssets = total[uint8(AssetType.Protected)].assets;
    }

    /// @inheritdoc ISilo
    function getCollateralAndDebtAssets()
        external
        view
        virtual
        returns (uint256 totalCollateralAssets, uint256 totalDebtAssets)
    {
        totalCollateralAssets = total[uint8(AssetType.Collateral)].assets;
        totalDebtAssets = total[uint8(AssetType.Debt)].assets;
    }

    // ERC4626

    /// @inheritdoc IERC4626
    function asset() external view virtual returns (address assetTokenAddress) {
        return sharedStorage.siloConfig.getAssetForSilo(address(this));
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
        return _callMaxDepositOrMint(total[uint8(AssetType.Collateral)].assets);
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
        (maxAssets,) = _callMaxWithdraw(sharedStorage.siloConfig, _owner, AssetType.Collateral);
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
        (, shares) = _withdraw(_assets, 0 /* shares */, _receiver, _owner, msg.sender, AssetType.Collateral);
    }

    /// @inheritdoc IERC4626
    function maxRedeem(address _owner) external view virtual returns (uint256 maxShares) {
        (, maxShares) = _callMaxWithdraw(sharedStorage.siloConfig, _owner, AssetType.Collateral);
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
    function maxDeposit(address /* _receiver */, CollateralType _assetType)
        external
        view
        virtual
        returns (uint256 maxAssets)
    {
        return _callMaxDepositOrMint(total[uint8(_assetType)].assets);
    }

    /// @inheritdoc ISilo
    function previewDeposit(uint256 _assets, CollateralType _assetType) external view virtual returns (uint256 shares) {
        return _previewDeposit(_assets, _assetType);
    }

    /// @inheritdoc ISilo
    function deposit(uint256 _assets, address _receiver, CollateralType _assetType)
        external
        virtual
        returns (uint256 shares)
    {
        (, shares) = _deposit(_assets, 0, /* shares */ _receiver, _assetType);
    }

    /// @inheritdoc ISilo
    function maxMint(address /* _receiver */, CollateralType _assetType)
        external
        view
        virtual
        returns (uint256 maxShares)
    {
        (address protectedToken, address collateralToken, ) = sharedStorage.siloConfig.getShareTokens(address(this));
        address shareToken = _assetType == CollateralType.Collateral ? collateralToken : protectedToken;

        return _callMaxDepositOrMint(IShareToken(shareToken).totalSupply());
    }

    /// @inheritdoc ISilo
    function previewMint(uint256 _shares, CollateralType _assetType) external view virtual returns (uint256 assets) {
        return _previewMint(_shares, _assetType);
    }

    /// @inheritdoc ISilo
    function mint(uint256 _shares, address _receiver, CollateralType _assetType)
        external
        virtual
        returns (uint256 assets)
    {
        (assets,) = _deposit(0 /* assets */, _shares, _receiver, _assetType);
    }

    /// @inheritdoc ISilo
    function maxWithdraw(address _owner, CollateralType _assetType) external view virtual returns (uint256 maxAssets) {
        (maxAssets,) = _callMaxWithdraw(sharedStorage.siloConfig, _owner, _assetType);
    }

    /// @inheritdoc ISilo
    function previewWithdraw(uint256 _assets, CollateralType _assetType)
        external
        view
        virtual
        returns (uint256 shares)
    {
        return _previewWithdraw(_assets, _assetType);
    }

    /// @inheritdoc ISilo
    function withdraw(uint256 _assets, address _receiver, address _owner, CollateralType _assetType)
        external
        virtual
        returns (uint256 shares)
    {
        (, shares) = _withdraw(_assets, 0 /* shares */, _receiver, _owner, msg.sender, _assetType);
    }

    /// @inheritdoc ISilo
    function maxRedeem(address _owner, CollateralType _assetType) external view virtual returns (uint256 maxShares) {
        (, maxShares) = _callMaxWithdraw(sharedStorage.siloConfig, _owner, _assetType);
    }

    /// @inheritdoc ISilo
    function previewRedeem(uint256 _shares, CollateralType _assetType) external view virtual returns (uint256 assets) {
        return _previewRedeem(_shares, _assetType);
    }

    /// @inheritdoc ISilo
    function redeem(uint256 _shares, address _receiver, address _owner, CollateralType _assetType)
        external
        virtual
        returns (uint256 assets)
    {
        (assets,) = _withdraw(0 /* assets */, _shares, _receiver, _owner, msg.sender, _assetType);
    }

    /// @inheritdoc ISilo
    function transitionCollateral( // solhint-disable-line function-max-lines
        uint256 _shares,
        address _owner,
        CollateralType _withdrawType
    )
        external
        virtual
        returns (uint256 assets)
    {
        uint256 toShares;

        (assets, toShares) = Actions.transitionCollateral(sharedStorage, _shares, _owner, _withdrawType, total);

        if (_withdrawType == CollateralType.Collateral) {
            emit Withdraw(msg.sender, _owner, _owner, assets, _shares);
            emit DepositProtected(msg.sender, _owner, assets, toShares);
        } else {
            emit WithdrawProtected(msg.sender, _owner, _owner, assets, _shares);
            emit Deposit(msg.sender, _owner, assets, toShares);
        }
    }

    /// @inheritdoc ISilo
    function maxBorrow(address _borrower, bool _sameAsset) external view virtual returns (uint256 maxAssets) {
        (maxAssets,) = SiloLendingLib.maxBorrow(sharedStorage.siloConfig, _borrower, _sameAsset);
    }

    /// @inheritdoc ISilo
    function previewBorrow(uint256 _assets) external view virtual returns (uint256 shares) {
        (uint256 totalSiloAssets, uint256 totalShares) = _getTotalAssetsAndTotalSharesWithInterest(AssetType.Debt);

        return SiloMathLib.convertToShares(
            _assets, totalSiloAssets, totalShares, Rounding.BORROW_TO_SHARES, AssetType.Debt
        );
    }

    function switchCollateralTo(bool _sameAsset) external virtual {
        Actions.switchCollateralTo(sharedStorage, _sameAsset);
        emit CollateralTypeChanged(msg.sender, _sameAsset);
    }

    /// @inheritdoc ISilo
    // solhint-disable-next-line code-complexity, function-max-lines
    function leverageSameAsset(
        uint256 _depositAssets,
        uint256 _borrowAssets,
        address _borrower,
        CollateralType _assetType
    )
        external
        virtual
        returns (uint256 depositedShares, uint256 borrowedShares)
    {
        (
            depositedShares, borrowedShares
        ) = Actions.leverageSameAsset(
            sharedStorage,
            _depositAssets,
            _borrowAssets,
            _borrower,
            _assetType,
            total[uint8(AssetType.Collateral)].assets,
            total[uint8(AssetType.Debt)],
            total[uint8(_assetType)]
        );

        emit Borrow(msg.sender, _borrower, _borrower, _borrowAssets, borrowedShares);
        emit Deposit(msg.sender, _borrower, _depositAssets, depositedShares);
    }

    /// @inheritdoc ISilo
    function borrow(uint256 _assets, address _receiver, address _borrower, bool _sameAsset)
        external
        virtual
        returns (uint256 shares)
    {
        (
            , shares
        ) = _borrow(_assets, 0 /* shares */, _receiver, _borrower, _sameAsset, false /* _leverage */, "" /* data */);
    }

    /// @inheritdoc ISilo
    function maxBorrowShares(address _borrower, bool _sameAsset) external view virtual returns (uint256 maxShares) {
        (,maxShares) = SiloLendingLib.maxBorrow(sharedStorage.siloConfig, _borrower, _sameAsset);
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
        ) = _borrow(0 /* assets */, _shares, _receiver, _borrower, _sameAsset, false /* _leverage */, "" /* data */);
    }

    /// @inheritdoc ISilo
    function maxRepay(address _borrower) external view virtual returns (uint256 assets) {
        ISiloConfig.ConfigData memory configData = sharedStorage.siloConfig.getConfig(address(this));
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
        ISiloConfig.ConfigData memory configData = sharedStorage.siloConfig.getConfig(address(this));
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
        maxLoan = _token == sharedStorage.siloConfig.getAssetForSilo(address(this))
            ? IERC20(_token).balanceOf(address(this))
            : 0;
    }

    /// @inheritdoc IERC3156FlashLender
    function flashFee(address _token, uint256 _amount) external view virtual returns (uint256 fee) {
        fee = SiloStdLib.flashFee(sharedStorage.siloConfig, _token, _amount);
    }

    /// @inheritdoc IERC3156FlashLender
    function flashLoan(IERC3156FlashBorrower _receiver, address _token, uint256 _amount, bytes calldata _data)
        external
        virtual
        returns (bool success)
    {
        success = Actions.flashLoan( sharedStorage, _receiver, _token, _amount, siloData, _data);
        if (success) emit FlashLoan(_amount);
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
        (, shares) = _borrow(_assets, 0 /* _shares */, address(_receiver), _borrower, _sameAsset, true, _data);
    }

    /// @inheritdoc ISilo
    function accrueInterest() external virtual returns (uint256 accruedInterest) {
        ISiloConfig.ConfigData memory cfg = sharedStorage.siloConfig.getConfig(address(this));
        accruedInterest = _callAccrueInterestForAsset(cfg.interestRateModel, cfg.daoFee, cfg.deployerFee, address(0));
    }

    /// @inheritdoc ISilo
    function accrueInterestForConfig(address _interestRateModel, uint256 _daoFee, uint256 _deployerFee)
        external
        virtual
    {
        if (msg.sender != address(sharedStorage.siloConfig)) revert OnlySiloConfig();

        _callAccrueInterestForAsset(_interestRateModel, _daoFee, _deployerFee, address(0) /* no other silo */);
    }

    /// @inheritdoc ISilo
    function withdrawFees() external virtual {
        Actions.withdrawFees(this, siloData);
    }

    // TODO can we optimise this? maybe add as args to methods
    function getRawLiquidity() public view virtual returns (uint256 liquidity) {
        liquidity = SiloMathLib.liquidity(total[uint8(AssetType.Collateral)].assets, total[uint8(AssetType.Debt)].assets);
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
            sharedStorage.siloConfig,
            _withdrawAssetsFromCollateral,
            _withdrawAssetsFromProtected,
            _borrower,
            _liquidator,
            _receiveSToken,
            getRawLiquidity(),
            total
        );
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
        // TODO make sure total are updated when we call accrue interest from SiloConfig
        (assets, shares) = Actions.deposit( sharedStorage, _assets, _shares, _receiver, _assetType, total[uint8(_assetType)]);

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
        (assets, shares) = Actions.withdraw(
            sharedStorage,
            WithdrawArgs({
                assets: _assets,
                shares: _shares,
                receiver: _receiver,
                owner: _owner,
                spender: _spender,
                assetType: _assetType
            }),
            total[uint8(_assetType)]
        );

        if (_assetType == AssetType.Collateral) {
            emit Withdraw(msg.sender, _receiver, _owner, assets, shares);
        } else {
            emit WithdrawProtected(msg.sender, _receiver, _owner, assets, shares);
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
        (assets, shares) = Actions.borrow(
            sharedStorage,
            BorrowArgs({
                assets: _assets,
                shares: _shares,
                receiver: _receiver,
                borrower: _borrower,
                sameAsset: _sameAsset,
                leverage: _leverage,
                totalCollateralAssets: total[uint8(AssetType.Collateral)].assets
            }),
            total[uint8(AssetType.Debt)],
            _data
        );

        emit Borrow(msg.sender, _receiver, _borrower, assets, shares);
    }

    /// @param _liquidation TRUE when call is from liquidator module
    function _repay(uint256 _assets, uint256 _shares, address _borrower, address _repayer, bool _liquidation)
        internal
        virtual
        returns (uint256 assets, uint256 shares)
    {
        (
            assets, shares
        ) = Actions.repay(
            sharedStorage,
            _assets,
            _shares,
            _borrower,
            _repayer,
            _liquidation,
            total[uint8(AssetType.Debt)]
        );

        emit Repay(_repayer, _borrower, assets, shares);
    }

    function _getTotalAssetsAndTotalSharesWithInterest(AssetType _assetType)
        internal
        view
        returns (uint256 assets, uint256 shares)
    {
        ISiloConfig.ConfigData memory configData = sharedStorage.siloConfig.getConfig(address(this));
        (assets, shares) = SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(configData, _assetType);
    }

    function _getShareToken() internal view virtual override returns (address collateralShareToken) {
        (, collateralShareToken,) = sharedStorage.siloConfig.getShareTokens(address(this));
    }

    function _previewMint(uint256 _shares, CollateralType _assetType) internal view virtual returns (uint256 assets) {
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
            _assetType == AssetType.Protected ? total[uint8(AssetType.Protected)].assets : 0 // will be calculated internally
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

        accruedInterest = SiloLendingLib.accrueInterestForAsset(
            _interestRateModel,
            _daoFee,
            _deployerFee,
            siloData,
            total[uint8(AssetType.Collateral)],
            total[uint8(AssetType.Debt)]
        );

        if (accruedInterest != 0) emit AccruedInterest(accruedInterest);
    }
}
