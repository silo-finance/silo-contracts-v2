// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {MathUpgradeable} from "openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol";
import {SafeERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import {ISilo, ISiloLiquidation} from "./interfaces/ISilo.sol";
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
import {SiloLiquidationExecLib} from "./lib/SiloLiquidationExecLib.sol";
import {LeverageReentrancyGuard} from "./utils/LeverageReentrancyGuard.sol";

// Keep ERC4626 ordering
// solhint-disable ordering

// TODO make sure we revert on zero deposit, borrow etc

contract Silo is Initializable, SiloERC4626, ReentrancyGuardUpgradeable, LeverageReentrancyGuard {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    string public constant VERSION = "2.0.0";

    bytes32 public constant FLASHLOAN_CALLBACK = keccak256("ERC3156FlashBorrower.onFlashLoan");
    bytes32 public constant LEVERAGE_CALLBACK = keccak256("ILeverageBorrower.onLeverage");
    
    ISiloFactory public immutable factory;

    ISiloConfig public config;

    SiloData public siloData;

    /// @dev silo is just for one asset, but this one asset can be of three types, so we store `assets` byType
    mapping(AssetType => Assets) internal _total;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(ISiloFactory _factory) {
        _disableInitializers();
        factory = _factory;
    }

    /// @notice Sets configuration
    /// @param _config address of ISiloConfig with full config for this Silo
    /// @param _modelConfigAddress address of a config contract used by model
    function initialize(ISiloConfig _config, address _modelConfigAddress) external virtual initializer {
        __ReentrancyGuard_init();
        __LeverageReentrancyGuard_init();

        config = _config;

        ISiloConfig.ConfigData memory configData = _config.getConfig(address(this));
        IInterestRateModel(configData.interestRateModel).connect(_modelConfigAddress);
    }

    function siloId() external view virtual returns (uint256) {
        return config.SILO_ID();
    }

    function utilizationData() external view virtual returns (UtilizationData memory) {
        return UtilizationData({
            collateralAssets: _total[AssetType.Collateral].assets,
            debtAssets: _total[AssetType.Debt].assets,
            interestRateTimestamp: siloData.interestRateTimestamp
        });
    }

    function getLiquidity() public view virtual returns (uint256 liquidity) {
        liquidity = SiloMathLib.liquidity(_total[AssetType.Collateral].assets, _total[AssetType.Debt].assets);
    }

    function isSolvent(address _borrower) external view virtual returns (bool) {
        (ISiloConfig.ConfigData memory collateralConfig, ISiloConfig.ConfigData memory debtConfig) =
            config.getConfigs(address(this));

        if (!SiloSolvencyLib.validConfigOrder(collateralConfig.debtShareToken, debtConfig.debtShareToken, _borrower)) {
            (collateralConfig, debtConfig) = (debtConfig, collateralConfig);
        }

        return SiloSolvencyLib.isSolvent(collateralConfig, debtConfig, _borrower, AccrueInterestInMemory.Yes);
    }

    function depositPossible(address _depositor) external view virtual returns (bool) {
        ISiloConfig.ConfigData memory configData = config.getConfig(address(this));

        return SiloERC4626Lib.depositPossible(configData.debtShareToken, _depositor);
    }

    function borrowPossible(address _borrower) external view virtual returns (bool) {
        ISiloConfig.ConfigData memory configData = config.getConfig(address(this));

        return SiloLendingLib.borrowPossible(
            configData.protectedShareToken, configData.collateralShareToken, configData.borrowable, _borrower
        );
    }

    function getMaxLtv() external view virtual returns (uint256) {
        ISiloConfig.ConfigData memory configData = config.getConfig(address(this));

        return configData.maxLtv;
    }

    function getLt() external view virtual returns (uint256) {
        ISiloConfig.ConfigData memory configData = config.getConfig(address(this));

        return configData.lt;
    }

    function getProtectedAssets() external view virtual returns (uint256) {
        return _total[AssetType.Protected].assets;
    }

    function getCollateralAssets() external view virtual returns (uint256 totalCollateralAssets) {
        totalCollateralAssets = _total[AssetType.Collateral].assets;
    }

    function getDebtAssets() external view virtual returns (uint256 totalDebtAssets) {
        totalDebtAssets = _total[AssetType.Debt].assets;
    }

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

    function asset() external view virtual returns (address assetTokenAddress) {
        return config.getAssetForSilo(address(this));
    }

    function totalAssets() external view virtual returns (uint256 totalManagedAssets) {
        ISiloConfig.ConfigData memory configData = config.getConfig(address(this));

        (totalManagedAssets,) = SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(configData, AssetType.Collateral);
    }

    /// @notice Converts assets to shares for collateral and protected collateral
    /// @dev For debt, use `convertToShares(uint256 _assets, AssetType _assetType)` with `AssetType.Debt`
    function convertToShares(uint256 _assets) external view virtual returns (uint256 shares) {
        ISiloConfig.ConfigData memory configData = config.getConfig(address(this));

        (uint256 totalSiloAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(configData, AssetType.Collateral);

        return SiloMathLib.convertToShares(
            _assets, totalSiloAssets, totalShares, MathUpgradeable.Rounding.Down, AssetType.Collateral
        );
    }

    /// @notice Converts shares to assets for collateral and protected collateral
    /// @dev For debt, use `convertToAssets(uint256 _shares, AssetType _assetType)` with `AssetType.Debt`
    function convertToAssets(uint256 _shares) external view virtual returns (uint256 assets) {
        ISiloConfig.ConfigData memory configData = config.getConfig(address(this));

        (uint256 totalSiloAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(configData, AssetType.Collateral);

        return SiloMathLib.convertToAssets(
            _shares, totalSiloAssets, totalShares, MathUpgradeable.Rounding.Down, AssetType.Collateral
        );
    }

    function maxDeposit(address _receiver) external view virtual returns (uint256 maxAssets) {
        return SiloERC4626Lib.maxDepositOrMint(config, _receiver);
    }

    function previewDeposit(uint256 _assets) external view virtual returns (uint256 shares) {
        ISiloConfig.ConfigData memory configData = config.getConfig(address(this));

        (uint256 totalSiloAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(configData, AssetType.Collateral);

        return SiloMathLib.convertToShares(
            _assets, totalSiloAssets, totalShares, MathUpgradeable.Rounding.Down, AssetType.Collateral
        );
    }

    function deposit(uint256 _assets, address _receiver) external virtual nonReentrant returns (uint256 shares) {
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

    function maxMint(address _receiver) external view virtual returns (uint256 maxShares) {
        return SiloERC4626Lib.maxDepositOrMint(config, _receiver);
    }

    function previewMint(uint256 _shares) external view virtual returns (uint256 assets) {
        ISiloConfig.ConfigData memory configData = config.getConfig(address(this));

        (uint256 totalSiloAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(configData, AssetType.Collateral);

        return SiloMathLib.convertToAssets(
            _shares, totalSiloAssets, totalShares, MathUpgradeable.Rounding.Down, AssetType.Collateral
        );
    }

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

    function maxWithdraw(address _owner) external view virtual returns (uint256 maxAssets) {
        (maxAssets,) = SiloERC4626Lib.maxWithdraw(
            config, _owner, AssetType.Collateral, _total[AssetType.Collateral].assets, getLiquidity()
        );
    }

    function previewWithdraw(uint256 _assets) external view virtual returns (uint256 shares) {
        ISiloConfig.ConfigData memory configData = config.getConfig(address(this));

        (uint256 totalSiloAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(configData, AssetType.Collateral);

        return SiloMathLib.convertToShares(
            _assets, totalSiloAssets, totalShares, MathUpgradeable.Rounding.Up, AssetType.Collateral
        );
    }

    function withdraw(uint256 _assets, address _receiver, address _owner)
        external
        virtual
        nonReentrant
        leverageNonReentrant
        returns (uint256 shares)
    {
        (, shares) = _withdraw(
            SiloERC4626Lib.WithdrawParams({
                assets: _assets,
                shares: 0,
                receiver: _receiver,
                owner: _owner,
                spender: msg.sender,
                assetType: AssetType.Collateral
            })
        );
    }

    function maxRedeem(address _owner) external view virtual returns (uint256 maxShares) {
        (, maxShares) = SiloERC4626Lib.maxWithdraw(
            config, _owner, AssetType.Collateral, _total[AssetType.Collateral].assets, getLiquidity()
        );
    }

    function previewRedeem(uint256 _shares) external view virtual returns (uint256 assets) {
        ISiloConfig.ConfigData memory configData = config.getConfig(address(this));

        (uint256 totalSiloAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(configData, AssetType.Collateral);

        return SiloMathLib.convertToAssets(
            _shares, totalSiloAssets, totalShares, MathUpgradeable.Rounding.Down, AssetType.Collateral
        );
    }

    function redeem(uint256 _shares, address _receiver, address _owner)
        external
        virtual
        nonReentrant
        leverageNonReentrant
        returns (uint256 assets)
    {
        // avoid magic number 0
        uint256 zeroAssets = 0;

        (assets,) = _withdraw(
            SiloERC4626Lib.WithdrawParams({
                assets: zeroAssets,
                shares: _shares,
                receiver: _receiver,
                owner: _owner,
                spender: msg.sender,
                assetType: AssetType.Collateral
            })
        );
    }

    function convertToShares(uint256 _assets, AssetType _assetType) external view virtual returns (uint256 shares) {
        ISiloConfig.ConfigData memory configData = config.getConfig(address(this));

        (uint256 totalSiloAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(configData, _assetType);

        return SiloMathLib.convertToShares(
            _assets, totalSiloAssets, totalShares, MathUpgradeable.Rounding.Down, _assetType
        );
    }

    function convertToAssets(uint256 _shares, AssetType _assetType) external view virtual returns (uint256 assets) {
        ISiloConfig.ConfigData memory configData = config.getConfig(address(this));

        (uint256 totalSiloAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(configData, _assetType);

        return SiloMathLib.convertToAssets(
            _shares, totalSiloAssets, totalShares, MathUpgradeable.Rounding.Down, _assetType
        );
    }

    function maxDeposit(address _receiver, AssetType /* _assetType */ )
        external
        view
        virtual
        returns (uint256 maxAssets)
    {
        return SiloERC4626Lib.maxDepositOrMint(config, _receiver);
    }

    function previewDeposit(uint256 _assets, AssetType _assetType) external view virtual returns (uint256 shares) {
        if (_assetType == AssetType.Debt) revert ISilo.WrongAssetType();

        ISiloConfig.ConfigData memory configData = config.getConfig(address(this));

        (uint256 totalSiloAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(configData, _assetType);

        return SiloMathLib.convertToShares(
            _assets, totalSiloAssets, totalShares, MathUpgradeable.Rounding.Down, AssetType.Collateral
        );
    }

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

    function maxMint(address _receiver, AssetType /* _assetType */ )
        external
        view
        virtual
        returns (uint256 maxShares)
    {
        return SiloERC4626Lib.maxDepositOrMint(config, _receiver);
    }

    function previewMint(uint256 _shares, AssetType _assetType) external view virtual returns (uint256 assets) {
        if (_assetType == AssetType.Debt) revert ISilo.WrongAssetType();

        ISiloConfig.ConfigData memory configData = config.getConfig(address(this));

        (uint256 totalSiloAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(configData, _assetType);

        return SiloMathLib.convertToAssets(
            _shares, totalSiloAssets, totalShares, MathUpgradeable.Rounding.Down, _assetType
        );
    }

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

    function maxWithdraw(address _owner, AssetType _assetType) external view virtual returns (uint256 maxAssets) {
        (maxAssets,) =
            SiloERC4626Lib.maxWithdraw(config, _owner, _assetType, _total[_assetType].assets, getLiquidity());
    }

    function previewWithdraw(uint256 _assets, AssetType _assetType) external view virtual returns (uint256 shares) {
        if (_assetType == AssetType.Debt) revert ISilo.WrongAssetType();

        ISiloConfig.ConfigData memory configData = config.getConfig(address(this));

        (uint256 totalSiloAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(configData, _assetType);

        return SiloMathLib.convertToShares(
            _assets, totalSiloAssets, totalShares, MathUpgradeable.Rounding.Down, _assetType
        );
    }

    function withdraw(uint256 _assets, address _receiver, address _owner, AssetType _assetType)
        external
        virtual
        nonReentrant
        leverageNonReentrant
        returns (uint256 shares)
    {
        (, shares) = _withdraw(
            SiloERC4626Lib.WithdrawParams({
                assets: _assets,
                shares: 0,
                receiver: _receiver,
                owner: _owner,
                spender: msg.sender,
                assetType: _assetType
            })
        );
    }

    function maxRedeem(address _owner, AssetType _assetType) external view virtual returns (uint256 maxShares) {
        (, maxShares) =
            SiloERC4626Lib.maxWithdraw(config, _owner, _assetType, _total[_assetType].assets, getLiquidity());
    }

    function previewRedeem(uint256 _shares, AssetType _assetType) external view virtual returns (uint256 assets) {
        if (_assetType == AssetType.Debt) revert ISilo.WrongAssetType();

        ISiloConfig.ConfigData memory configData = config.getConfig(address(this));

        (uint256 totalSiloAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(configData, _assetType);

        return SiloMathLib.convertToAssets(
            _shares, totalSiloAssets, totalShares, MathUpgradeable.Rounding.Down, _assetType
        );
    }

    function redeem(uint256 _shares, address _receiver, address _owner, AssetType _assetType)
        external
        virtual
        nonReentrant
        leverageNonReentrant
        returns (uint256 assets)
    {
        (assets,) = _withdraw(
            SiloERC4626Lib.WithdrawParams({
                assets: 0,
                shares: _shares,
                receiver: _receiver,
                owner: _owner,
                spender: msg.sender,
                assetType: _assetType
            })
        );
    }

    function transitionCollateral(uint256 _shares, address _owner, AssetType _withdrawType)
        external
        virtual
        nonReentrant
        leverageNonReentrant
        returns (uint256 assets)
    {
        if (_withdrawType == AssetType.Debt) revert ISilo.WrongAssetType();

        (, ISiloConfig.ConfigData memory configData) = _accrueInterest();

        uint256 toShares;

        {
            (AssetType depositType, address shareTokenFrom, address shareTokenTo, uint256 liquidity) =
                _withdrawType == AssetType.Collateral
                ? (AssetType.Protected, configData.collateralShareToken, configData.protectedShareToken, getLiquidity())
                : (
                    AssetType.Collateral,
                    configData.protectedShareToken,
                    configData.collateralShareToken,
                    _total[_withdrawType].assets
                );

            (assets, _shares) = SiloERC4626Lib.withdraw(
                address(0), // empty token address because we dont want to do transfer
                shareTokenFrom,
                SiloERC4626Lib.WithdrawParams({
                    assets: 0,
                    shares: _shares,
                    receiver: _owner,
                    owner: _owner,
                    spender: msg.sender,
                    assetType: _withdrawType
                }),
                liquidity,
                _total[_withdrawType]
            );

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

    // Lending

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

    function previewBorrow(uint256 _assets) external view virtual returns (uint256 shares) {
        ISiloConfig.ConfigData memory configData = config.getConfig(address(this));

        (uint256 totalSiloAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(configData, AssetType.Debt);

        return SiloMathLib.convertToShares(
            _assets, totalSiloAssets, totalShares, MathUpgradeable.Rounding.Up, AssetType.Debt
        );
    }

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

    function maxBorrowShares(address _borrower) external view virtual returns (uint256 maxShares) {
        (
            ISiloConfig.ConfigData memory debtConfig, ISiloConfig.ConfigData memory collateralConfig
        ) = config.getConfigs(address(this));

        (uint256 totalSiloAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(debtConfig, AssetType.Debt);

        (, maxShares) = SiloLendingLib.maxBorrow(collateralConfig, debtConfig, _borrower, totalSiloAssets, totalShares);
    }

    function previewBorrowShares(uint256 _shares) external view virtual returns (uint256 assets) {
        ISiloConfig.ConfigData memory configData = config.getConfig(address(this));

        (uint256 totalSiloAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(configData, AssetType.Debt);

        return SiloMathLib.convertToAssets(
            _shares, totalSiloAssets, totalShares, MathUpgradeable.Rounding.Up, AssetType.Debt
        );
    }

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

    function maxRepay(address _borrower) external view virtual returns (uint256 assets) {
        ISiloConfig.ConfigData memory configData = config.getConfig(address(this));
        uint256 shares = IShareToken(configData.debtShareToken).balanceOf(_borrower);

        (uint256 totalSiloAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(configData, AssetType.Debt);

        return SiloMathLib.convertToAssets(
            shares, totalSiloAssets, totalShares, MathUpgradeable.Rounding.Up, AssetType.Debt
        );
    }

    function previewRepay(uint256 _assets) external view virtual returns (uint256 shares) {
        ISiloConfig.ConfigData memory configData = config.getConfig(address(this));

        (uint256 totalSiloAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(configData, AssetType.Debt);

        return SiloMathLib.convertToShares(
            _assets, totalSiloAssets, totalShares, MathUpgradeable.Rounding.Down, AssetType.Debt
        );
    }

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

    function maxRepayShares(address _borrower) external view virtual returns (uint256 shares) {
        ISiloConfig.ConfigData memory configData = config.getConfig(address(this));
        shares = IShareToken(configData.debtShareToken).balanceOf(_borrower);
    }

    function previewRepayShares(uint256 _shares) external view virtual returns (uint256 assets) {
        ISiloConfig.ConfigData memory configData = config.getConfig(address(this));

        (uint256 totalSiloAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(configData, AssetType.Debt);

        return SiloMathLib.convertToAssets(
            _shares, totalSiloAssets, totalShares, MathUpgradeable.Rounding.Down, AssetType.Debt
        );
    }

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

    function maxFlashLoan(address _token) external view virtual returns (uint256 maxLoan) {
        maxLoan =
            _token == config.getAssetForSilo(address(this)) ? IERC20Upgradeable(_token).balanceOf(address(this)) : 0;
    }

    function flashFee(address _token, uint256 _amount) external view virtual returns (uint256 fee) {
        fee = SiloStdLib.flashFee(config, _token, _amount);
    }

    function flashLoan(IERC3156FlashBorrower _receiver, address _token, uint256 _amount, bytes calldata _data)
        external
        virtual
        leverageNonReentrant
        returns (bool success)
    {
        // flashFee will revert for wrong token
        uint256 fee = SiloStdLib.flashFee(config, _token, _amount);

        IERC20Upgradeable(_token).safeTransfer(address(_receiver), _amount);

        if (_receiver.onFlashLoan(msg.sender, _token, _amount, fee, _data) != FLASHLOAN_CALLBACK) {
            revert FlashloanFailed();
        }

        IERC20Upgradeable(_token).safeTransferFrom(address(_receiver), address(this), _amount + fee);

        unchecked {
            // we operating on chunks of real tokens, so overflow should not happen
            // fee is simply to small to overflow on cast to uint192, even if, we will get lower fee
            siloData.daoAndDeployerFees += uint192(fee);
        }

        success = true;
    }

    function leverage(uint256 _assets, ILeverageBorrower _receiver, address _borrower, bytes calldata _data)
        external
        virtual
        leverageNonReentrant
        returns (uint256 shares)
    {
        // config for this Silo is always at index 0
        (ISiloConfig.ConfigData memory debtConfig, ISiloConfig.ConfigData memory collateralConfig) =
            config.getConfigs(address(this));

        if (
            !SiloLendingLib.borrowPossible(
                debtConfig.protectedShareToken, debtConfig.collateralShareToken, debtConfig.borrowable, _borrower
            )
        ) revert ISilo.BorrowNotPossible();

        _accrueInterest(debtConfig.interestRateModel, debtConfig.daoFeeInBp, debtConfig.deployerFeeInBp);

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
        if (_receiver.onLeverage(msg.sender, _borrower, debtConfig.token, assets, _data) != LEVERAGE_CALLBACK) {
            revert LeverageFailed();
        }

        if (!SiloSolvencyLib.isBelowMaxLtv(collateralConfig, debtConfig, _borrower, AccrueInterestInMemory.No)) {
            revert AboveMaxLtv();
        }
    }

    function accrueInterest() external virtual returns (uint256 accruedInterest) {
        (accruedInterest,) = _accrueInterest();
    }

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
    ) external virtual {
        (ISiloConfig.ConfigData memory debtConfig, ISiloConfig.ConfigData memory collateralConfig) =
            config.getConfigs(address(this));

        if (_collateralAsset != collateralConfig.token) revert UnexpectedCollateralToken();
        if (_debtAsset != debtConfig.token) revert UnexpectedDebtToken();

        _accrueInterest(debtConfig.interestRateModel, debtConfig.daoFeeInBp, debtConfig.deployerFeeInBp);
        ISilo(debtConfig.otherSilo).accrueInterest();

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

    function _accrueInterest()
        internal
        virtual
        returns (uint256 accruedInterest, ISiloConfig.ConfigData memory configData)
    {
        configData = config.getConfig(address(this));

        accruedInterest = SiloLendingLib.accrueInterestForAsset(
            configData.interestRateModel,
            configData.daoFeeInBp,
            configData.deployerFeeInBp,
            siloData,
            _total[AssetType.Collateral],
            _total[AssetType.Debt]
        );
    }

    function _accrueInterest(address _interestRateModel, uint256 _daoFeeInBp, uint256 _deployerFeeInBp)
        internal
        virtual
        returns (uint256 accruedInterest)
    {
        accruedInterest = SiloLendingLib.accrueInterestForAsset(
            _interestRateModel,
            _daoFeeInBp,
            _deployerFeeInBp,
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

    function _withdraw(SiloERC4626Lib.WithdrawParams memory _params)
        internal
        virtual
        returns (uint256 assets, uint256 shares)
    {
        if (_params.assetType == AssetType.Debt) revert ISilo.WrongAssetType();

        (ISiloConfig.ConfigData memory collateralConfig, ISiloConfig.ConfigData memory debtConfig) =
            config.getConfigs(address(this));

        _accrueInterest();

        address shareToken = _params.assetType == AssetType.Collateral
            ? collateralConfig.collateralShareToken
            : collateralConfig.protectedShareToken;

        uint256 liquidity = _params.assetType == AssetType.Collateral
            ? getLiquidity()
            : _total[_params.assetType].assets;

        (assets, shares) =
            SiloERC4626Lib.withdraw(collateralConfig.token, shareToken, _params, liquidity, _total[_params.assetType]);

        if (_params.assetType == AssetType.Collateral) {
            emit Withdraw(msg.sender, _params.receiver, _params.owner, assets, shares);
        } else {
            emit WithdrawProtected(msg.sender, _params.receiver, _params.owner, assets, shares);
        }

        // `_params.owner` must be solvent
        if (!SiloSolvencyLib.isSolvent(collateralConfig, debtConfig, _params.owner, AccrueInterestInMemory.No)) {
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

        _accrueInterest(debtConfig.interestRateModel, debtConfig.daoFeeInBp, debtConfig.deployerFeeInBp);

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

    function _getShareToken() internal view virtual override returns (address collateralShareToken) {
        (, collateralShareToken,) = config.getShareTokens(address(this));
    }
}
