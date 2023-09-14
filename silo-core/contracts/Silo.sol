// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {MathUpgradeable} from "openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol";
import {SafeERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import {ISilo} from "./interfaces/ISilo.sol";
import {IERC3156FlashBorrower} from "./interfaces/IERC3156FlashBorrower.sol";
import {ILeverageBorrower} from "./interfaces/ILeverageBorrower.sol";
import {ISiloConfig} from "./interfaces/ISiloConfig.sol";
import {ISiloFactory} from "./interfaces/ISiloFactory.sol";
import {IInterestRateModel} from "./interfaces/IInterestRateModel.sol";

import {SiloStdLib} from "./lib/SiloStdLib.sol";
import {SiloSolvencyLib} from "./lib/SiloSolvencyLib.sol";
import {SiloLendingLib} from "./lib/SiloLendingLib.sol";
import {SiloERC4626Lib} from "./lib/SiloERC4626Lib.sol";
import {SiloLiquidationLib} from "./lib/SiloLiquidationLib.sol";
import {LeverageReentrancyGuard} from "./utils/LeverageReentrancyGuard.sol";

// Keep ERC4626 ordering
// solhint-disable ordering

contract Silo is Initializable, ISilo, ReentrancyGuardUpgradeable, LeverageReentrancyGuard {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    string public constant VERSION = "2.0.0";

    bytes32 public constant FLASHLOAN_CALLBACK = keccak256("ERC3156FlashBorrower.onFlashLoan");
    bytes32 public constant LEVERAGE_CALLBACK = keccak256("ILeverageBorrower.onLeverage");

    ISiloFactory public immutable factory;

    ISiloConfig public config;

    mapping(address => AssetStorage) public assetStorage;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(ISiloFactory _factory) {
        _disableInitializers();
        factory = _factory;
    }

    /// @notice Sets configuration
    /// @param _config address of ISiloConfig with full config for this Silo
    /// @param _modelConfigAddress address of a config contract used by model
    // TODO: _modelConfigAddress cannot be part of initialize becasue it's not generic
    function initialize(ISiloConfig _config, address _modelConfigAddress) external virtual initializer {
        __ReentrancyGuard_init();
        __LeverageReentrancyGuard_init();

        config = _config;

        ISiloConfig.ConfigData memory configData = _config.getConfig(address(this));
        IInterestRateModel(configData.interestRateModel).connect(configData.token, _modelConfigAddress);
    }

    function siloId() external view virtual returns (uint256) {
        return config.SILO_ID();
    }

    function utilizationData(address _asset) external view virtual returns (UtilizationData memory) {
        return UtilizationData({
            collateralAssets: assetStorage[_asset].collateralAssets,
            debtAssets: assetStorage[_asset].debtAssets,
            interestRateTimestamp: assetStorage[_asset].interestRateTimestamp
        });
    }

    function isSolvent(address _borrower) external view virtual returns (bool) {
        (ISiloConfig.ConfigData memory configData0, ISiloConfig.ConfigData memory configData1) =
            config.getConfigs(address(this));

        return SiloSolvencyLib.isSolvent(configData0, configData1, _borrower, AccrueInterestInMemory.Yes);
    }

    function depositPossible(address _depositor) external view virtual returns (bool) {
        ISiloConfig.ConfigData memory configData = config.getConfig(address(this));

        return SiloERC4626Lib.depositPossible(configData, _depositor);
    }

    function borrowPossible(address _borrower) external view virtual returns (bool) {
        ISiloConfig.ConfigData memory configData = config.getConfig(address(this));

        return SiloLendingLib.borrowPossible(configData, _borrower);
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
        return assetStorage[config.getAssetForSilo(address(this))].protectedAssets;
    }

    function getCollateralAssets() external view virtual returns (uint256) {
        return assetStorage[config.getAssetForSilo(address(this))].collateralAssets;
    }

    function getDebtAssets() external view virtual returns (uint256) {
        return assetStorage[config.getAssetForSilo(address(this))].debtAssets;
    }

    function getFeesAndFeeReceivers()
        external
        view
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

        return SiloStdLib.amountWithInterest(
            configData.token, assetStorage[configData.token].collateralAssets, configData.interestRateModel
        );
    }

    function convertToShares(uint256 _assets) external view virtual returns (uint256 shares) {
        return SiloERC4626Lib.convertToAssetsOrToShares(
            config, _assets, AssetType.Collateral, UseAssets.Yes, MathUpgradeable.Rounding.Down, assetStorage
        );
    }

    function convertToAssets(uint256 _shares) external view virtual returns (uint256 assets) {
        return SiloERC4626Lib.convertToAssetsOrToShares(
            config, _shares, AssetType.Collateral, UseAssets.No, MathUpgradeable.Rounding.Down, assetStorage
        );
    }

    function maxDeposit(address _receiver) external view virtual returns (uint256 maxAssets) {
        return SiloERC4626Lib.maxDepositOrMint(config, _receiver);
    }

    function previewDeposit(uint256 _assets) external view virtual returns (uint256 shares) {
        return SiloERC4626Lib.convertToAssetsOrToShares(
            config, _assets, AssetType.Collateral, UseAssets.Yes, MathUpgradeable.Rounding.Down, assetStorage
        );
    }

    function deposit(uint256 _assets, address _receiver) external virtual nonReentrant returns (uint256 shares) {
        // avoid magic number 0
        uint256 depositShares = 0;

        (, shares) = _deposit(_assets, depositShares, _receiver, AssetType.Collateral);
    }

    function maxMint(address _receiver) external view virtual returns (uint256 maxShares) {
        return SiloERC4626Lib.maxDepositOrMint(config, _receiver);
    }

    function previewMint(uint256 _shares) external view virtual returns (uint256 assets) {
        return SiloERC4626Lib.convertToAssetsOrToShares(
            config, _shares, AssetType.Collateral, UseAssets.No, MathUpgradeable.Rounding.Down, assetStorage
        );
    }

    function mint(uint256 _shares, address _receiver) external virtual nonReentrant returns (uint256 assets) {
        // avoid magic number 0
        uint256 mintAssets = 0;

        (assets,) = _deposit(mintAssets, _shares, _receiver, AssetType.Collateral);
    }

    function maxWithdraw(address _owner) external view virtual returns (uint256 maxAssets) {
        (maxAssets,) = SiloERC4626Lib.maxWithdraw(config, _owner, AssetType.Collateral, assetStorage);
    }

    function previewWithdraw(uint256 _assets) external view virtual returns (uint256 shares) {
        return SiloERC4626Lib.convertToAssetsOrToShares(
            config, _assets, AssetType.Collateral, UseAssets.Yes, MathUpgradeable.Rounding.Up, assetStorage
        );
    }

    function withdraw(uint256 _assets, address _receiver, address _owner)
        external
        virtual
        nonReentrant
        leverageNonReentrant
        returns (uint256 shares)
    {
        // avoid magic number 0
        uint256 zeroShares = 0;

        (, shares) = _withdraw(
            SiloERC4626Lib.WithdrawParams({
                assets: _assets,
                shares: zeroShares,
                receiver: _receiver,
                owner: _owner,
                spender: msg.sender,
                doTransfer: ISilo.TokenTransfer.Yes,
                assetType: AssetType.Collateral
            })
        );
    }

    function maxRedeem(address _owner) external view virtual returns (uint256 maxShares) {
        (, maxShares) = SiloERC4626Lib.maxWithdraw(config, _owner, AssetType.Collateral, assetStorage);
    }

    function previewRedeem(uint256 _shares) external view virtual returns (uint256 assets) {
        return SiloERC4626Lib.convertToAssetsOrToShares(
            config, _shares, AssetType.Collateral, UseAssets.No, MathUpgradeable.Rounding.Down, assetStorage
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
                doTransfer: ISilo.TokenTransfer.Yes,
                assetType: AssetType.Collateral
            })
        );
    }

    // Protected

    function convertToShares(uint256 _assets, AssetType _assetType) external view virtual returns (uint256 shares) {
        return SiloERC4626Lib.convertToAssetsOrToShares(
            config, _assets, _assetType, UseAssets.Yes, MathUpgradeable.Rounding.Down, assetStorage
        );
    }

    function convertToAssets(uint256 _shares, AssetType _assetType) external view virtual returns (uint256 assets) {
        return SiloERC4626Lib.convertToAssetsOrToShares(
            config, _shares, _assetType, UseAssets.No, MathUpgradeable.Rounding.Down, assetStorage
        );
    }

    function maxDeposit(address _receiver, AssetType /*_assetType*/ )
        external
        view
        virtual
        returns (uint256 maxAssets)
    {
        return SiloERC4626Lib.maxDepositOrMint(config, _receiver);
    }

    function previewDeposit(uint256 _assets, AssetType _assetType) external view virtual returns (uint256 shares) {
        return SiloERC4626Lib.convertToAssetsOrToShares(
            config, _assets, _assetType, UseAssets.Yes, MathUpgradeable.Rounding.Down, assetStorage
        );
    }

    function deposit(uint256 _assets, address _receiver, AssetType _assetType)
        external
        virtual
        nonReentrant
        returns (uint256 shares)
    {
        // avoid magic number 0
        uint256 depositShares = 0;

        (, shares) = _deposit(_assets, depositShares, _receiver, _assetType);
    }

    function maxMint(address _receiver, AssetType /*_assetType*/ )
        external
        view
        virtual
        returns (uint256 maxShares)
    {
        return SiloERC4626Lib.maxDepositOrMint(config, _receiver);
    }

    function previewMint(uint256 _shares, AssetType _assetType) external view virtual returns (uint256 assets) {
        return SiloERC4626Lib.convertToAssetsOrToShares(
            config, _shares, _assetType, UseAssets.No, MathUpgradeable.Rounding.Down, assetStorage
        );
    }

    function mint(uint256 _shares, address _receiver, AssetType _assetType)
        external
        virtual
        nonReentrant
        returns (uint256 assets)
    {
        // avoid magic number 0
        uint256 mintAssets = 0;

        (assets,) = _deposit(mintAssets, _shares, _receiver, _assetType);
    }

    function maxWithdraw(address _owner, AssetType _assetType) external view virtual returns (uint256 maxAssets) {
        (maxAssets,) = SiloERC4626Lib.maxWithdraw(config, _owner, _assetType, assetStorage);
    }

    function previewWithdraw(uint256 _assets, AssetType _assetType) external view virtual returns (uint256 shares) {
        return SiloERC4626Lib.convertToAssetsOrToShares(
            config, _assets, _assetType, UseAssets.Yes, MathUpgradeable.Rounding.Down, assetStorage
        );
    }

    function withdraw(uint256 _assets, address _receiver, address _owner, AssetType _assetType)
        external
        virtual
        nonReentrant
        leverageNonReentrant
        returns (uint256 shares)
    {
        // avoid magic number 0
        uint256 zeroShares = 0;

        (, shares) = _withdraw(
            SiloERC4626Lib.WithdrawParams({
                assets: _assets,
                shares: zeroShares,
                receiver: _receiver,
                owner: _owner,
                spender: msg.sender,
                doTransfer: ISilo.TokenTransfer.Yes,
                assetType: _assetType
            })
        );
    }

    function maxRedeem(address _owner, AssetType _assetType) external view virtual returns (uint256 maxShares) {
        (, maxShares) = SiloERC4626Lib.maxWithdraw(config, _owner, _assetType, assetStorage);
    }

    function previewRedeem(uint256 _shares, AssetType _assetType) external view virtual returns (uint256 assets) {
        return SiloERC4626Lib.convertToAssetsOrToShares(
            config, _shares, _assetType, UseAssets.No, MathUpgradeable.Rounding.Down, assetStorage
        );
    }

    function redeem(uint256 _shares, address _receiver, address _owner, AssetType _assetType)
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
                doTransfer: ISilo.TokenTransfer.Yes,
                assetType: _assetType
            })
        );
    }

    function transitionCollateralToProtected(uint256 _shares, address _owner)
        external
        virtual
        nonReentrant
        leverageNonReentrant
        returns (uint256 assets)
    {
        uint256 shares;
        uint256 toShares;

        (assets, shares, toShares) = _transitionCollateral(_shares, _owner, AssetType.Collateral);

        emit Withdraw(msg.sender, _owner, _owner, assets, shares);
        emit DepositProtected(msg.sender, _owner, assets, toShares);
    }

    function transitionCollateralFromProtected(uint256 _shares, address _owner)
        external
        virtual
        nonReentrant
        leverageNonReentrant
        returns (uint256 assets)
    {
        uint256 shares;
        uint256 toShares;

        (assets, shares, toShares) = _transitionCollateral(_shares, _owner, AssetType.Protected);

        emit WithdrawProtected(msg.sender, _owner, _owner, assets, shares);
        emit Deposit(msg.sender, _owner, assets, toShares);
    }

    // Lending

    function maxBorrow(address _borrower) external view virtual returns (uint256 maxAssets) {
        (maxAssets,) = SiloLendingLib.maxBorrow(config, _borrower, assetStorage);
    }

    function previewBorrow(uint256 _assets) external view virtual returns (uint256 shares) {
        return SiloERC4626Lib.convertToAssetsOrToShares(
            config, _assets, AssetType.Debt, UseAssets.Yes, MathUpgradeable.Rounding.Up, assetStorage
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

        (, shares) = _borrow(_assets, borrowSharesZero, _receiver, _borrower, UseAssets.Yes);
    }

    function maxBorrowShares(address _borrower) external view virtual returns (uint256 maxShares) {
        (, maxShares) = SiloLendingLib.maxBorrow(config, _borrower, assetStorage);
    }

    function previewBorrowShares(uint256 _shares) external view virtual returns (uint256 assets) {
        return SiloERC4626Lib.convertToAssetsOrToShares(
            config, _shares, AssetType.Debt, UseAssets.No, MathUpgradeable.Rounding.Up, assetStorage
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
        uint256 borrowAssets = 0;

        (assets,) = _borrow(borrowAssets, _shares, _receiver, _borrower, UseAssets.No);
    }

    function maxRepay(address _borrower) external view virtual returns (uint256 assets) {
        (assets,) = SiloLendingLib.maxRepay(config, _borrower, assetStorage);
    }

    function previewRepay(uint256 _assets) external view virtual returns (uint256 shares) {
        return SiloERC4626Lib.convertToAssetsOrToShares(
            config, _assets, AssetType.Debt, UseAssets.Yes, MathUpgradeable.Rounding.Down, assetStorage
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

        (, shares) = _repay(_assets, repaySharesZero, _borrower, UseAssets.Yes);
    }

    function maxRepayShares(address _borrower) external view virtual returns (uint256 shares) {
        (, shares) = SiloLendingLib.maxRepay(config, _borrower, assetStorage);
    }

    function previewRepayShares(uint256 _shares) external view virtual returns (uint256 assets) {
        return SiloERC4626Lib.convertToAssetsOrToShares(
            config, _shares, AssetType.Debt, UseAssets.No, MathUpgradeable.Rounding.Down, assetStorage
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
        uint256 repayAssets = 0;

        (assets,) = _repay(repayAssets, _shares, _borrower, UseAssets.No);
    }

    function maxFlashLoan(address _token) external view returns (uint256 maxLoan) {
        maxLoan =
            _token == config.getAssetForSilo(address(this)) ? IERC20Upgradeable(_token).balanceOf(address(this)) : 0;
    }

    function flashFee(address _token, uint256 _amount) external view returns (uint256 fee) {
        fee = SiloStdLib.flashFee(config, _token, _amount);
    }

    function flashLoan(IERC3156FlashBorrower _receiver, address _token, uint256 _amount, bytes calldata _data)
        external
        leverageNonReentrant
        returns (bool success)
    {
        // flashFee will revert for wrong token
        uint256 fee = SiloStdLib.flashFee(config, _token, _amount);

        IERC20Upgradeable(_token).safeTransferFrom(address(this), address(_receiver), _amount);

        if (_receiver.onFlashLoan(msg.sender, _token, _amount, fee, _data) != FLASHLOAN_CALLBACK) {
            revert FlashloanFailed();
        }

        IERC20Upgradeable(_token).safeTransferFrom(address(_receiver), address(this), _amount + fee);

        assetStorage[_token].daoAndDeployerFees += fee;

        success = true;
    }

    function leverage(uint256 _assets, ILeverageBorrower _receiver, address _borrower, bytes calldata _data)
        external
        virtual
        leverageNonReentrant
        returns (uint256 shares)
    {
        (ISiloConfig.ConfigData memory configData0, ISiloConfig.ConfigData memory configData1) =
            config.getConfigs(address(this));

        // config for this Silo is always at index 0
        if (!SiloLendingLib.borrowPossible(configData0, _borrower)) revert BorrowNotPossible();

        SiloLendingLib.accrueInterestForAsset(configData0, assetStorage[configData0.token]);

        uint256 assets;

        // avoid magic number 0
        uint256 borrowSharesZero = 0;

        (assets, shares) = SiloLendingLib.borrow(
            configData0,
            _assets,
            borrowSharesZero,
            address(_receiver),
            _borrower,
            msg.sender,
            UseAssets.Yes,
            assetStorage[configData0.token]
        );

        emit Borrow(msg.sender, address(_receiver), _borrower, assets, shares);
        emit Leverage();

        // allow for deposit reentry only to provide collateral
        if (_receiver.onLeverage(msg.sender, _borrower, configData0.token, assets, _data) != LEVERAGE_CALLBACK) {
            revert LeverageFailed();
        }

        if (!SiloSolvencyLib.isBelowMaxLtv(configData0, configData1, _borrower, AccrueInterestInMemory.No)) {
            revert AboveMaxLtv();
        }
    }

    function accrueInterest() external virtual returns (uint256 accruedInterest) {
        ISiloConfig.ConfigData memory configData = config.getConfig(address(this));

        accruedInterest = SiloLendingLib.accrueInterestForAsset(configData, assetStorage[configData.token]);
    }

    function withdrawFees() external virtual {
        SiloStdLib.withdrawFees(config, factory, assetStorage);
    }

    function _deposit(uint256 _assets, uint256 _shares, address _receiver, AssetType _assetType)
        internal
        virtual
        returns (uint256 assets, uint256 shares)
    {
        ISiloConfig.ConfigData memory configData = config.getConfig(address(this));

        if (!SiloERC4626Lib.depositPossible(configData, _receiver)) revert DepositNotPossible();

        SiloLendingLib.accrueInterestForAsset(configData, assetStorage[configData.token]);

        (assets, shares) = SiloERC4626Lib.deposit(
            configData,
            msg.sender,
            _receiver,
            _assets,
            _shares,
            _assetType,
            _assets == 0 ? UseAssets.No : UseAssets.Yes,
            TokenTransfer.Yes,
            assetStorage[configData.token]
        );

        if (_assetType == AssetType.Protected) {
            emit DepositProtected(msg.sender, _receiver, assets, shares);
        } else {
            emit Deposit(msg.sender, _receiver, assets, shares);
        }
    }

    function _withdraw(SiloERC4626Lib.WithdrawParams memory _params)
        internal
        virtual
        returns (uint256 assets, uint256 shares)
    {
        (ISiloConfig.ConfigData memory configData0, ISiloConfig.ConfigData memory configData1) =
            config.getConfigs(address(this));

        SiloLendingLib.accrueInterestForAsset(configData0, assetStorage[configData0.token]);

        ISilo.UseAssets useAssets = _params.assets == 0 ? UseAssets.No : UseAssets.Yes;

        (assets, shares) = SiloERC4626Lib.withdraw(configData0, _params, useAssets, assetStorage[configData0.token]);

        if (_params.assetType == AssetType.Protected) {
            emit WithdrawProtected(msg.sender, _params.receiver, _params.owner, assets, shares);
        } else if (_params.assetType == AssetType.Collateral) {
            emit Withdraw(msg.sender, _params.receiver, _params.owner, assets, shares);
        } else {
            revert ISilo.WrongAssetType();
        }

        // `_params.owner` must be solvent
        if (!SiloSolvencyLib.isSolvent(configData0, configData1, _params.owner, AccrueInterestInMemory.No)) {
            revert NotSolvent();
        }
    }

    function _borrow(uint256 _assets, uint256 _shares, address _receiver, address _borrower, UseAssets _useAssets)
        internal
        virtual
        returns (uint256 assets, uint256 shares)
    {
        (ISiloConfig.ConfigData memory configData0, ISiloConfig.ConfigData memory configData1) =
            config.getConfigs(address(this));

        // config for this Silo is always at index 0
        if (!SiloLendingLib.borrowPossible(configData0, _borrower)) revert BorrowNotPossible();

        SiloLendingLib.accrueInterestForAsset(configData0, assetStorage[configData0.token]);

        (assets, shares) = SiloLendingLib.borrow(
            configData0, _assets, _shares, _receiver, _borrower, msg.sender, _useAssets, assetStorage[configData0.token]
        );

        emit Borrow(msg.sender, _receiver, _borrower, assets, shares);

        if (!SiloSolvencyLib.isBelowMaxLtv(configData0, configData1, _borrower, AccrueInterestInMemory.No)) {
            revert AboveMaxLtv();
        }
    }

    function _repay(uint256 _assets, uint256 _shares, address _borrower, UseAssets _useAssets)
        internal
        virtual
        returns (uint256 assets, uint256 shares)
    {
        ISiloConfig.ConfigData memory configData = config.getConfig(address(this));

        SiloLendingLib.accrueInterestForAsset(configData, assetStorage[configData.token]);

        (assets, shares) = SiloLendingLib.repay(
            configData, _assets, _shares, _borrower, msg.sender, _useAssets, assetStorage[configData.token]
        );

        emit Repay(msg.sender, _borrower, assets, shares);
    }

    function _transitionCollateral(uint256 _shares, address _owner, ISilo.AssetType _assetType)
        internal
        virtual
        returns (uint256 assets, uint256 shares, uint256 toShares)
    {
        ISiloConfig.ConfigData memory configData = config.getConfig(address(this));

        SiloLendingLib.accrueInterestForAsset(configData, assetStorage[configData.token]);

        return SiloLendingLib.transitionCollateral(
            configData, _shares, _owner, msg.sender, _assetType, assetStorage[configData.token]
        );
    }

    // TODO: allow selfliquidate
    function liquidationCall( // solhint-disable function-max-lines
        address _collateralAsset,
        address _debtAsset,
        address _borrower,
        uint256 _debtToCover,
        bool _receiveSToken
    ) external {
        (
            ISiloConfig.ConfigData memory debtConfig,
            ISiloConfig.ConfigData memory collateralConfig
        ) = config.getConfigs(address(this));

        if (_collateralAsset != collateralConfig.token) revert UnexpectedCollateralToken();
        if (_debtAsset != debtConfig.token) revert UnexpectedDebtToken();

        SiloLendingLib.accrueInterestForAsset(collateralConfig, assetStorage[collateralConfig.token]);
        SiloLendingLib.accrueInterestForAsset(debtConfig, assetStorage[debtConfig.token]);

        (
            uint256 receiveCollateralAssets,
            uint256 repayDebtAssets
        ) = SiloSolvencyLib.liquidationPreview(
            collateralConfig, debtConfig, _borrower, _debtToCover, collateralConfig.liquidationFee
        );

        if (receiveCollateralAssets == 0 || repayDebtAssets == 0) revert UserIsSolvent();

        // always ZERO, we can receive shares, but we can not repay with shares
        // TODO good? If not good, we need either separate method or interface will not be the same as AAVE
        uint256 repayDebtShares;

        SiloLendingLib.repay(
            debtConfig,
            repayDebtAssets,
            repayDebtShares,
            _borrower,
            msg.sender,
            UseAssets.Yes,
            assetStorage[debtConfig.token]
        );

        (uint256 borrowerCollateralAssets,) = SiloSolvencyLib.assetBalanceOfWithInterest(
            collateralConfig.silo,
            collateralConfig.interestRateModel,
            collateralConfig.token,
            collateralConfig.collateralShareToken,
            _borrower,
            ISilo.AccrueInterestInMemory.No,
            MathUpgradeable.Rounding.Down
        );

        uint256 withdrawFromCollateral;
        uint256 withdrawFromProtected;

        unchecked {
            (withdrawFromCollateral, withdrawFromProtected) = receiveCollateralAssets > borrowerCollateralAssets
                // safe to unchecked because of above condition
                ? (borrowerCollateralAssets, receiveCollateralAssets - borrowerCollateralAssets)
                : (receiveCollateralAssets, 0);
        }

        if (withdrawFromCollateral != 0) {
            // TODO must be call to other silo
            SiloERC4626Lib.withdraw(
                collateralConfig,
                SiloERC4626Lib.WithdrawParams({
                    assets: withdrawFromCollateral,
                    shares: 0,
                    receiver: msg.sender,
                    owner: _borrower,
                    spender: _borrower,
                    doTransfer: ISilo.TokenTransfer.Yes,
                    assetType: ISilo.AssetType.Collateral
                }),
                ISilo.UseAssets.Yes,
                assetStorage[collateralConfig.token]
            );
        }

        if (withdrawFromProtected != 0) {
            // TODO must be call to other silo
            SiloERC4626Lib.withdraw(
                collateralConfig,
                SiloERC4626Lib.WithdrawParams({
                    assets: withdrawFromProtected,
                    shares: 0,
                    receiver: msg.sender,
                    owner: _borrower,
                    spender: _borrower,
                    doTransfer: ISilo.TokenTransfer.Yes,
                    assetType: ISilo.AssetType.Protected
                }),
                ISilo.UseAssets.Yes,
                assetStorage[collateralConfig.token]
            );
        }

        emit LiquidationCall(msg.sender, _receiveSToken);
    }
}
