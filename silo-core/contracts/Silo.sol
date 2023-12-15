// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {MathUpgradeable} from "openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol";
import {SafeERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import {ISilo, ISiloLiquidation, IERC4626, IERC3156FlashLender} from "./interfaces/ISilo.sol";
import {ISiloOracle} from "./interfaces/ISiloOracle.sol";
import {IShareToken} from "./interfaces/IShareToken.sol";

import {IERC3156FlashBorrower} from "./interfaces/IERC3156FlashBorrower.sol";
import {ILeverageBorrower} from "./interfaces/ILeverageBorrower.sol";
import {ISiloConfig} from "./interfaces/ISiloConfig.sol";
import {ISiloFactory} from "./interfaces/ISiloFactory.sol";
import {IInterestRateModel} from "./interfaces/IInterestRateModel.sol";

import {SiloERC4626} from "./utils/SiloERC4626.sol";
import {SiloStdLib} from "./lib/SiloStdLib.sol";
import {SiloSolvencyLib} from "./lib/SiloSolvencyLib.sol";
import {SiloLendingLib} from "./lib/SiloLendingLib.sol";
import {SiloERC4626Lib} from "./lib/SiloERC4626Lib.sol";
import {SiloMathLib} from "./lib/SiloMathLib.sol";
import {SiloLiquidationLib} from "./lib/SiloLiquidationLib.sol";
import {SiloLiquidationExecLib} from "./lib/SiloLiquidationExecLib.sol";
import {LeverageReentrancyGuard} from "./utils/LeverageReentrancyGuard.sol";

// Keep ERC4626 ordering
// solhint-disable ordering

/// @title Silo vault with lending and borrowing functionality
/// @notice Silo is a ERC4626-compatible vault that allows users to deposit collateral and borrow debt. This contract
/// is deployed twice for each asset for two-asset lending markets.
/// Version: 2.0.0
contract Silo is Initializable, SiloERC4626, ReentrancyGuardUpgradeable, LeverageReentrancyGuard {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    bytes32 internal constant _LEVERAGE_CALLBACK = keccak256("ILeverageBorrower.onLeverage");

    ISiloFactory public immutable factory;

    ISiloConfig public config;

    SiloData public siloData;

    /// @dev silo is just for one asset, but this one asset can be of three types, so we store `assets` by type. We use
    /// struct instead of uint256 to pass storage reference to functions.
    mapping(AssetType => Assets) internal _total;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(ISiloFactory _siloFactory) {
        _disableInitializers();
        factory = _siloFactory;
    }

    /// @inheritdoc ISilo
    function initialize(ISiloConfig _siloConfig, address _modelConfigAddress) external virtual initializer {
        __ReentrancyGuard_init();
        __LeverageReentrancyGuard_init();

        config = _siloConfig;

        address interestRateModel = _siloConfig.getConfig(address(this)).interestRateModel;
        IInterestRateModel(interestRateModel).connect(_modelConfigAddress);
    }

    /// @inheritdoc ISilo
    function utilizationData() external view virtual returns (UtilizationData memory) {
        return UtilizationData({
            collateralAssets: _total[AssetType.Collateral].assets,
            debtAssets: _total[AssetType.Debt].assets,
            interestRateTimestamp: siloData.interestRateTimestamp
        });
    }

    /// @inheritdoc ISilo
    function getLiquidity() public view virtual returns (uint256 liquidity) {
        liquidity = SiloMathLib.liquidity(_total[AssetType.Collateral].assets, _total[AssetType.Debt].assets);
    }

    /// @inheritdoc ISilo
    function isSolvent(address _borrower) external view virtual returns (bool) {
        (
            ISiloConfig.ConfigData memory collateralConfig, ISiloConfig.ConfigData memory debtConfig
        ) = _getOrderedConfigs(_borrower);

        uint256 debtShareBalance = IShareToken(debtConfig.debtShareToken).balanceOf(_borrower);

        return SiloSolvencyLib.isSolvent(
            collateralConfig, debtConfig, _borrower, AccrueInterestInMemory.Yes, debtShareBalance
        );
    }

    /// @inheritdoc ISilo
    function depositPossible(address _depositor) external view virtual returns (bool) {
        address debtShareToken = config.getConfig(address(this)).debtShareToken;
        return SiloERC4626Lib.depositPossible(debtShareToken, _depositor);
    }

    /// @inheritdoc ISilo
    function borrowPossible(address _borrower) external view virtual returns (bool) {
        ISiloConfig.ConfigData memory configData = config.getConfig(address(this));

        return SiloLendingLib.borrowPossible(
            configData.protectedShareToken, configData.collateralShareToken, _borrower
        );
    }

    /// @inheritdoc ISilo
    function getMaxLtv() external view virtual returns (uint256 maxLtv) {
        maxLtv = config.getConfig(address(this)).maxLtv;
    }

    /// @inheritdoc ISilo
    function getLt() external view virtual returns (uint256 lt) {
        lt = config.getConfig(address(this)).lt;
    }

    /// @inheritdoc ISilo
    function getLtv(address _borrower) external view virtual returns (uint256 ltv) {
        (
            ISiloConfig.ConfigData memory collateralConfig, ISiloConfig.ConfigData memory debtConfig
        ) = _getOrderedConfigs(_borrower);

        ltv = SiloSolvencyLib.getLtv(
            collateralConfig,
            debtConfig,
            _borrower,
            ISilo.OracleType.Solvency,
            AccrueInterestInMemory.Yes,
            IShareToken(debtConfig.debtShareToken).balanceOf(_borrower)
        );
    }

    /// @inheritdoc ISilo
    function getProtectedAssets() external view virtual returns (uint256 totalProtectedAssets) {
        totalProtectedAssets = _total[AssetType.Protected].assets;
    }

    /// @inheritdoc ISilo
    function getCollateralAssets() external view virtual returns (uint256 totalCollateralAssets) {
        totalCollateralAssets = _total[AssetType.Collateral].assets;
    }

    /// @inheritdoc ISilo
    function getDebtAssets() external view virtual returns (uint256 totalDebtAssets) {
        totalDebtAssets = _total[AssetType.Debt].assets;
    }

    /// @inheritdoc ISilo
    function getCollateralAndProtectedAssets()
        external
        view
        virtual
        returns (uint256 totalCollateralAssets, uint256 totalProtectedAssets)
    {
        totalCollateralAssets = _total[AssetType.Collateral].assets;
        totalProtectedAssets = _total[AssetType.Protected].assets;
    }

    /// @inheritdoc ISilo
    function getFeesAndFeeReceivers()
        external
        view
        virtual
        returns (address daoFeeReceiver, address deployerFeeReceiver, uint256 daoFee, uint256 deployerFee)
    {
        (daoFeeReceiver, deployerFeeReceiver, daoFee, deployerFee,) =
            SiloStdLib.getFeesAndFeeReceiversWithAsset(config, factory);
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
            _assets, totalSiloAssets, totalShares, MathUpgradeable.Rounding.Down, AssetType.Collateral
        );
    }

    /// @inheritdoc IERC4626
    /// @dev For protected (non-borrowable) collateral and debt, use:
    /// `convertToAssets(uint256 _shares, AssetType _assetType)` with `AssetType.Protected` or `AssetType.Debt`
    function convertToAssets(uint256 _shares) external view virtual returns (uint256 assets) {
        (uint256 totalSiloAssets, uint256 totalShares) =
            _getTotalAssetsAndTotalSharesWithInterest(AssetType.Collateral);

        return SiloMathLib.convertToAssets(
            _shares, totalSiloAssets, totalShares, MathUpgradeable.Rounding.Down, AssetType.Collateral
        );
    }

    /// @inheritdoc IERC4626
    function maxDeposit(address _receiver) external view virtual returns (uint256 maxAssets) {
        return SiloERC4626Lib.maxDepositOrMint(config, _receiver);
    }

    /// @inheritdoc IERC4626
    function previewDeposit(uint256 _assets) external view virtual returns (uint256 shares) {
        (uint256 totalSiloAssets, uint256 totalShares) =
            _getTotalAssetsAndTotalSharesWithInterest(AssetType.Collateral);

        return SiloMathLib.convertToShares(
            _assets, totalSiloAssets, totalShares, MathUpgradeable.Rounding.Down, AssetType.Collateral
        );
    }

    /// @inheritdoc IERC4626
    function deposit(uint256 _assets, address _receiver)
        external
        virtual
        nonReentrant
        leverageNonReentrant
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
            IShareToken(configData.collateralShareToken),
            IShareToken(configData.debtShareToken)
        );
    }

    /// @inheritdoc IERC4626
    function maxMint(address _receiver) external view virtual returns (uint256 maxShares) {
        return SiloERC4626Lib.maxDepositOrMint(config, _receiver);
    }

    /// @inheritdoc IERC4626
    function previewMint(uint256 _shares) external view virtual returns (uint256 assets) {
        (uint256 totalSiloAssets, uint256 totalShares) =
            _getTotalAssetsAndTotalSharesWithInterest(AssetType.Collateral);

        return SiloMathLib.convertToAssets(
            _shares, totalSiloAssets, totalShares, MathUpgradeable.Rounding.Up, AssetType.Collateral
        );
    }

    /// @inheritdoc IERC4626
    function mint(uint256 _shares, address _receiver) external virtual nonReentrant returns (uint256 assets) {
        (, ISiloConfig.ConfigData memory configData) = _accrueInterest();

        (assets,) = _deposit(
            configData.token,
            0, // assets
            _shares,
            _receiver,
            AssetType.Collateral,
            IShareToken(configData.collateralShareToken),
            IShareToken(configData.debtShareToken)
        );
    }

    /// @inheritdoc IERC4626
    function maxWithdraw(address _owner) external view virtual returns (uint256 maxAssets) {
        (maxAssets,) = SiloERC4626Lib.maxWithdraw(
            config, _owner, AssetType.Collateral, _total[AssetType.Collateral].assets, getLiquidity()
        );
    }

    /// @inheritdoc IERC4626
    function previewWithdraw(uint256 _assets) external view virtual returns (uint256 shares) {
        (uint256 totalSiloAssets, uint256 totalShares) =
            _getTotalAssetsAndTotalSharesWithInterest(AssetType.Collateral);

        return SiloMathLib.convertToShares(
            _assets, totalSiloAssets, totalShares, MathUpgradeable.Rounding.Up, AssetType.Collateral
        );
    }

    /// @inheritdoc IERC4626
    function withdraw(uint256 _assets, address _receiver, address _owner)
        external
        virtual
        nonReentrant
        leverageNonReentrant
        returns (uint256 shares)
    {
        (, shares) = _withdraw(_assets, 0 /* shares */, _receiver, _owner, msg.sender, AssetType.Collateral);
    }

    /// @inheritdoc IERC4626
    function maxRedeem(address _owner) external view virtual returns (uint256 maxShares) {
        (, maxShares) = SiloERC4626Lib.maxWithdraw(
            config, _owner, AssetType.Collateral, _total[AssetType.Collateral].assets, getLiquidity()
        );
    }

    /// @inheritdoc IERC4626
    function previewRedeem(uint256 _shares) external view virtual returns (uint256 assets) {
        (uint256 totalSiloAssets, uint256 totalShares) =
            _getTotalAssetsAndTotalSharesWithInterest(AssetType.Collateral);

        return SiloMathLib.convertToAssets(
            _shares, totalSiloAssets, totalShares, MathUpgradeable.Rounding.Down, AssetType.Collateral
        );
    }

    /// @inheritdoc IERC4626
    function redeem(uint256 _shares, address _receiver, address _owner)
        external
        virtual
        nonReentrant
        leverageNonReentrant
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
            _assets, totalSiloAssets, totalShares, MathUpgradeable.Rounding.Down, _assetType
        );
    }

    /// @inheritdoc ISilo
    function convertToAssets(uint256 _shares, AssetType _assetType) external view virtual returns (uint256 assets) {
        (uint256 totalSiloAssets, uint256 totalShares) = _getTotalAssetsAndTotalSharesWithInterest(_assetType);

        return SiloMathLib.convertToAssets(
            _shares, totalSiloAssets, totalShares, MathUpgradeable.Rounding.Down, _assetType
        );
    }

    /// @inheritdoc ISilo
    function maxDeposit(address _receiver, AssetType /* _assetType */ )
        external
        view
        virtual
        returns (uint256 maxAssets)
    {
        return SiloERC4626Lib.maxDepositOrMint(config, _receiver);
    }

    /// @inheritdoc ISilo
    function previewDeposit(uint256 _assets, AssetType _assetType) external view virtual returns (uint256 shares) {
        if (_assetType == AssetType.Debt) revert ISilo.WrongAssetType();

        (uint256 totalSiloAssets, uint256 totalShares) = _getTotalAssetsAndTotalSharesWithInterest(_assetType);

        return SiloMathLib.convertToShares(
            _assets, totalSiloAssets, totalShares, MathUpgradeable.Rounding.Down, AssetType.Collateral
        );
    }

    /// @inheritdoc ISilo
    function deposit(uint256 _assets, address _receiver, AssetType _assetType)
        external
        virtual
        nonReentrant
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
            IShareToken(collateralShareToken),
            IShareToken(configData.debtShareToken)
        );
    }

    /// @inheritdoc ISilo
    function maxMint(address _receiver, AssetType /* _assetType */ )
        external
        view
        virtual
        returns (uint256 maxShares)
    {
        return SiloERC4626Lib.maxDepositOrMint(config, _receiver);
    }

    /// @inheritdoc ISilo
    function previewMint(uint256 _shares, AssetType _assetType) external view virtual returns (uint256 assets) {
        if (_assetType == AssetType.Debt) revert ISilo.WrongAssetType();

        (uint256 totalSiloAssets, uint256 totalShares) = _getTotalAssetsAndTotalSharesWithInterest(_assetType);

        return SiloMathLib.convertToAssets(
            _shares, totalSiloAssets, totalShares, MathUpgradeable.Rounding.Up, _assetType
        );
    }

    /// @inheritdoc ISilo
    function mint(uint256 _shares, address _receiver, AssetType _assetType)
        external
        virtual
        nonReentrant
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
            IShareToken(collateralShareToken),
            IShareToken(configData.debtShareToken)
        );
    }

    /// @inheritdoc ISilo
    function maxWithdraw(address _owner, AssetType _assetType) external view virtual returns (uint256 maxAssets) {
        (maxAssets,) =
            SiloERC4626Lib.maxWithdraw(config, _owner, _assetType, _total[_assetType].assets, getLiquidity());
    }

    /// @inheritdoc ISilo
    function previewWithdraw(uint256 _assets, AssetType _assetType) external view virtual returns (uint256 shares) {
        if (_assetType == AssetType.Debt) revert ISilo.WrongAssetType();

        (uint256 totalSiloAssets, uint256 totalShares) = _getTotalAssetsAndTotalSharesWithInterest(_assetType);

        return SiloMathLib.convertToShares(
            _assets, totalSiloAssets, totalShares, MathUpgradeable.Rounding.Down, _assetType
        );
    }

    /// @inheritdoc ISilo
    function withdraw(uint256 _assets, address _receiver, address _owner, AssetType _assetType)
        external
        virtual
        nonReentrant
        leverageNonReentrant
        returns (uint256 shares)
    {
        (, shares) = _withdraw(_assets, 0 /* shares */, _receiver, _owner, msg.sender, _assetType);
    }

    /// @inheritdoc ISilo
    function maxRedeem(address _owner, AssetType _assetType) external view virtual returns (uint256 maxShares) {
        (, maxShares) =
            SiloERC4626Lib.maxWithdraw(config, _owner, _assetType, _total[_assetType].assets, getLiquidity());
    }

    /// @inheritdoc ISilo
    function previewRedeem(uint256 _shares, AssetType _assetType) external view virtual returns (uint256 assets) {
        if (_assetType == AssetType.Debt) revert ISilo.WrongAssetType();

        (uint256 totalSiloAssets, uint256 totalShares) = _getTotalAssetsAndTotalSharesWithInterest(_assetType);

        return SiloMathLib.convertToAssets(
            _shares, totalSiloAssets, totalShares, MathUpgradeable.Rounding.Down, _assetType
        );
    }

    /// @inheritdoc ISilo
    function redeem(uint256 _shares, address _receiver, address _owner, AssetType _assetType)
        external
        virtual
        nonReentrant
        leverageNonReentrant
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
        nonReentrant
        leverageNonReentrant
        returns (uint256 assets)
    {
        if (_withdrawType == AssetType.Debt) revert ISilo.WrongAssetType();

        (, ISiloConfig.ConfigData memory configData) = _accrueInterest();

        uint256 toShares;

        { // Stack too deep
            (address shareTokenFrom, uint256 liquidity) = _withdrawType == AssetType.Collateral
                ? (configData.collateralShareToken, getLiquidity())
                : (configData.protectedShareToken, _total[AssetType.Protected].assets);

            (assets, _shares) = SiloERC4626Lib.transitionCollateralWithdraw(
                shareTokenFrom,
                _shares,
                _owner,
                msg.sender,
                _withdrawType,
                liquidity,
                _total[_withdrawType]
            );
        }

        { // Stack too deep
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
                IShareToken(configData.debtShareToken),
                _total[depositType]
            );
        }

        if (_withdrawType == AssetType.Collateral) {
            emit Withdraw(msg.sender, _owner, _owner, assets, _shares);
            emit DepositProtected(msg.sender, _owner, assets, toShares);
        } else {
            emit WithdrawProtected(msg.sender, _owner, _owner, assets, _shares);
            emit Deposit(msg.sender, _owner, assets, toShares);
        }
    }

    /// @inheritdoc ISilo
    function maxBorrow(address _borrower) external view virtual returns (uint256 maxAssets) {
        (
            ISiloConfig.ConfigData memory debtConfig, ISiloConfig.ConfigData memory collateralConfig
        ) = config.getConfigs(address(this));

        (uint256 totalDebtAssets, uint256 totalDebtShares) =
            SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(debtConfig, AssetType.Debt);

        (
            maxAssets,
        ) = SiloLendingLib.maxBorrow(collateralConfig, debtConfig, _borrower, totalDebtAssets, totalDebtShares);
    }

    /// @inheritdoc ISilo
    function previewBorrow(uint256 _assets) external view virtual returns (uint256 shares) {
        (uint256 totalSiloAssets, uint256 totalShares) = _getTotalAssetsAndTotalSharesWithInterest(AssetType.Debt);

        return SiloMathLib.convertToShares(
            _assets, totalSiloAssets, totalShares, MathUpgradeable.Rounding.Up, AssetType.Debt
        );
    }

    /// @inheritdoc ISilo
    function borrow(uint256 _assets, address _receiver, address _borrower)
        external
        virtual
        nonReentrant
        leverageNonReentrant
        returns (uint256 shares)
    {
        // avoid magic number 0
        uint256 borrowSharesZero = 0;

        (, shares) = _borrow(_assets, borrowSharesZero, _receiver, _borrower);
    }

    /// @inheritdoc ISilo
    function maxBorrowShares(address _borrower) external view virtual returns (uint256 maxShares) {
        (
            ISiloConfig.ConfigData memory debtConfig, ISiloConfig.ConfigData memory collateralConfig
        ) = config.getConfigs(address(this));

        (uint256 totalSiloAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(debtConfig, AssetType.Debt);

        (, maxShares) = SiloLendingLib.maxBorrow(collateralConfig, debtConfig, _borrower, totalSiloAssets, totalShares);
    }

    /// @inheritdoc ISilo
    function previewBorrowShares(uint256 _shares) external view virtual returns (uint256 assets) {
        (uint256 totalSiloAssets, uint256 totalShares) = _getTotalAssetsAndTotalSharesWithInterest(AssetType.Debt);

        return SiloMathLib.convertToAssets(
            _shares, totalSiloAssets, totalShares, MathUpgradeable.Rounding.Down, AssetType.Debt
        );
    }

    /// @inheritdoc ISilo
    function borrowShares(uint256 _shares, address _receiver, address _borrower)
        external
        virtual
        nonReentrant
        leverageNonReentrant
        returns (uint256 assets)
    {
        // avoid magic number 0
        uint256 zeroAssets = 0;

        (assets,) = _borrow(zeroAssets, _shares, _receiver, _borrower);
    }

    /// @inheritdoc ISilo
    function maxRepay(address _borrower) external view virtual returns (uint256 assets) {
        ISiloConfig.ConfigData memory configData = config.getConfig(address(this));
        uint256 shares = IShareToken(configData.debtShareToken).balanceOf(_borrower);

        (uint256 totalSiloAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(configData, AssetType.Debt);

        return SiloMathLib.convertToAssets(
            shares, totalSiloAssets, totalShares, MathUpgradeable.Rounding.Up, AssetType.Debt
        );
    }

    /// @inheritdoc ISilo
    function previewRepay(uint256 _assets) external view virtual returns (uint256 shares) {
        (uint256 totalSiloAssets, uint256 totalShares) = _getTotalAssetsAndTotalSharesWithInterest(AssetType.Debt);

        return SiloMathLib.convertToShares(
            _assets, totalSiloAssets, totalShares, MathUpgradeable.Rounding.Down, AssetType.Debt
        );
    }

    /// @inheritdoc ISilo
    function repay(uint256 _assets, address _borrower)
        external
        virtual
        nonReentrant
        leverageNonReentrant
        returns (uint256 shares)
    {
        // avoid magic number 0
        uint256 repaySharesZero = 0;

        (, shares) = _repay(_assets, repaySharesZero, _borrower);
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
            _shares, totalSiloAssets, totalShares, MathUpgradeable.Rounding.Up, AssetType.Debt
        );
    }

    /// @inheritdoc ISilo
    function repayShares(uint256 _shares, address _borrower)
        external
        virtual
        nonReentrant
        leverageNonReentrant
        returns (uint256 assets)
    {
        // avoid magic number 0
        uint256 zeroAssets = 0;

        (assets,) = _repay(zeroAssets, _shares, _borrower);
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
        leverageNonReentrant
        returns (bool success)
    {
        return SiloLendingLib.flashLoan(config, siloData, _receiver, _token, _amount, _data);
    }

    /// @inheritdoc ISilo
    function leverage(uint256 _assets, ILeverageBorrower _receiver, address _borrower, bytes calldata _data)
        external
        virtual
        leverageNonReentrant
        returns (uint256 shares)
    {
        // config for this Silo is always at index 0
        (ISiloConfig.ConfigData memory debtConfig, ISiloConfig.ConfigData memory collateralConfig) =
            config.getConfigs(address(this));

        _accrueInterest(debtConfig.interestRateModel, debtConfig.daoFee, debtConfig.deployerFee);

        uint256 assets;

        // avoid magic number 0
        uint256 borrowSharesZero = 0;

        (assets, shares) = SiloLendingLib.borrow(
            debtConfig,
            _assets,
            borrowSharesZero,
            address(_receiver),
            _borrower,
            msg.sender,
            _total[AssetType.Debt],
            _total[AssetType.Collateral].assets
        );

        emit Borrow(msg.sender, address(_receiver), _borrower, assets, shares);
        emit Leverage();

        // allow for deposit reentry only to provide collateral
        if (_receiver.onLeverage(msg.sender, _borrower, debtConfig.token, assets, _data) != _LEVERAGE_CALLBACK) {
            revert LeverageFailed();
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

    /// @inheritdoc ISilo
    function accrueInterest() external virtual returns (uint256 accruedInterest) {
        (accruedInterest,) = _accrueInterest();
    }

    /// @inheritdoc ISilo
    function withdrawFees() external virtual {
        SiloStdLib.withdrawFees(config, factory, siloData);
    }

    /// @dev it can be called on "debt silo" only
    /// @notice user can use this method to do self liquidation, it that case check for LT requirements will be ignored
    function liquidationCall(
        address _collateralAsset,
        address _debtAsset,
        address _borrower,
        uint256 _debtToCover,
        bool _receiveSToken
    ) external virtual leverageNonReentrant {
        (ISiloConfig.ConfigData memory debtConfig, ISiloConfig.ConfigData memory collateralConfig) =
            config.getConfigs(address(this));

        if (_collateralAsset != collateralConfig.token) revert UnexpectedCollateralToken();
        if (_debtAsset != debtConfig.token) revert UnexpectedDebtToken();

        _accrueInterest(debtConfig.interestRateModel, debtConfig.daoFee, debtConfig.deployerFee);
        ISilo(debtConfig.otherSilo).accrueInterest();

        if (collateralConfig.callBeforeQuote) {
            ISiloOracle(collateralConfig.solvencyOracle).beforeQuote(collateralConfig.token);
        }

        if (debtConfig.callBeforeQuote) {
            ISiloOracle(debtConfig.solvencyOracle).beforeQuote(debtConfig.token);
        }

        bool selfLiquidation = _borrower == msg.sender;

        (
            uint256 withdrawAssetsFromCollateral, uint256 withdrawAssetsFromProtected, uint256 repayDebtAssets
        ) = SiloLiquidationExecLib.getExactLiquidationAmounts(
            collateralConfig,
            debtConfig,
            _borrower,
            _debtToCover,
            selfLiquidation ? 0 : collateralConfig.liquidationFee,
            selfLiquidation
        );

        if (repayDebtAssets == 0) revert NoDebtToCover();

        // always ZERO, we can receive shares, but we can not repay with shares
        uint256 zeroShares;
        emit LiquidationCall(msg.sender, _receiveSToken);
        SiloLendingLib.repay(debtConfig, repayDebtAssets, zeroShares, _borrower, msg.sender, _total[AssetType.Debt]);

        ISiloLiquidation(debtConfig.otherSilo).withdrawCollateralsToLiquidator(
            withdrawAssetsFromCollateral, withdrawAssetsFromProtected, _borrower, msg.sender, _receiveSToken
        );
    }

    /// @dev that method allow to finish liquidation process by giving up collateral to liquidator
    function withdrawCollateralsToLiquidator(
        uint256 _withdrawAssetsFromCollateral,
        uint256 _withdrawAssetsFromProtected,
        address _borrower,
        address _liquidator,
        bool _receiveSToken
    ) external virtual {
        SiloLiquidationExecLib.withdrawCollateralsToLiquidator(
            config,
            _withdrawAssetsFromCollateral,
            _withdrawAssetsFromProtected,
            _borrower,
            _liquidator,
            _receiveSToken,
            getLiquidity(),
            _total
        );
    }

    /// @inheritdoc ISiloLiquidation
    function maxLiquidation(address _borrower)
        external
        view
        virtual
        returns (uint256 collateralToLiquidate, uint256 debtToRepay)
    {
        return SiloLiquidationExecLib.maxLiquidation(this, _borrower);
    }

    function _accrueInterest()
        internal
        virtual
        returns (uint256 accruedInterest, ISiloConfig.ConfigData memory configData)
    {
        configData = config.getConfig(address(this));

        accruedInterest = SiloLendingLib.accrueInterestForAsset(
            configData.interestRateModel,
            configData.daoFee,
            configData.deployerFee,
            siloData,
            _total[AssetType.Collateral],
            _total[AssetType.Debt]
        );
    }

    function _accrueInterest(address _interestRateModel, uint256 _daoFee, uint256 _deployerFee)
        internal
        virtual
        returns (uint256 accruedInterest)
    {
        accruedInterest = SiloLendingLib.accrueInterestForAsset(
            _interestRateModel,
            _daoFee,
            _deployerFee,
            siloData,
            _total[AssetType.Collateral],
            _total[AssetType.Debt]
        );
    }

    function _deposit(
        address _token,
        uint256 _assets,
        uint256 _shares,
        address _receiver,
        ISilo.AssetType _assetType,
        IShareToken _collateralShareToken,
        IShareToken _debtShareToken
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
            _debtShareToken,
            _total[_assetType]
        );

        if (_assetType == AssetType.Collateral) {
            emit Deposit(msg.sender, _receiver, assets, shares);
        } else {
            emit DepositProtected(msg.sender, _receiver, assets, shares);
        }
    }

    // solhint-disable-next-line function-max-lines
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

        (ISiloConfig.ConfigData memory collateralConfig, ISiloConfig.ConfigData memory debtConfig) =
            config.getConfigs(address(this));

        _accrueInterest();

        // this if helped with Stack too deep
        if (_assetType == AssetType.Collateral) {
            (assets, shares) = SiloERC4626Lib.withdraw(
                collateralConfig.token,
                collateralConfig.collateralShareToken,
                _assets,
                _shares,
                _receiver,
                _owner,
                _spender,
                _assetType,
                getLiquidity(),
                _total[AssetType.Collateral]
            );
        } else {
            (assets, shares) = SiloERC4626Lib.withdraw(
                collateralConfig.token,
                collateralConfig.protectedShareToken,
                _assets,
                _shares,
                _receiver,
                _owner,
                _spender,
                _assetType,
                _total[AssetType.Protected].assets,
                _total[AssetType.Protected]
            );
        }

        if (_assetType == AssetType.Collateral) {
            emit Withdraw(msg.sender, _receiver, _owner, assets, shares);
        } else {
            emit WithdrawProtected(msg.sender, _receiver, _owner, assets, shares);
        }

        uint256 debtShareBalance = IShareToken(debtConfig.debtShareToken).balanceOf(_owner);

        if (debtShareBalance == 0) {
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
                collateralConfig, debtConfig, _owner, AccrueInterestInMemory.No, debtShareBalance
            )
        ) {
            revert NotSolvent();
        }
    }

    function _borrow(uint256 _assets, uint256 _shares, address _receiver, address _borrower)
        internal
        virtual
        returns (uint256 assets, uint256 shares)
    {
        (ISiloConfig.ConfigData memory debtConfig, ISiloConfig.ConfigData memory collateralConfig) =
            config.getConfigs(address(this));

        _accrueInterest(debtConfig.interestRateModel, debtConfig.daoFee, debtConfig.deployerFee);

        (assets, shares) = SiloLendingLib.borrow(
            debtConfig,
            _assets,
            _shares,
            _receiver,
            _borrower,
            msg.sender,
            _total[AssetType.Debt],
            _total[AssetType.Collateral].assets
        );

        emit Borrow(msg.sender, _receiver, _borrower, assets, shares);

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

    function _repay(uint256 _assets, uint256 _shares, address _borrower)
        internal
        virtual
        returns (uint256 assets, uint256 shares)
    {
        (, ISiloConfig.ConfigData memory configData) = _accrueInterest();

        (assets, shares) =
            SiloLendingLib.repay(configData, _assets, _shares, _borrower, msg.sender, _total[AssetType.Debt]);

        emit Repay(msg.sender, _borrower, assets, shares);
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

    function _getOrderedConfigs(address _borrower)
        internal
        view
        virtual
        returns (ISiloConfig.ConfigData memory collateralConfig, ISiloConfig.ConfigData memory debtConfig) {
        (collateralConfig, debtConfig) = config.getConfigs(address(this));

        if (!SiloSolvencyLib.validConfigOrder(collateralConfig.debtShareToken, debtConfig.debtShareToken, _borrower)) {
            (collateralConfig, debtConfig) = (debtConfig, collateralConfig);
        }
    }
}
