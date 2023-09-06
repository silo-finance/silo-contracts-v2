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
import {LeverageReentrancyGuard} from "./utils/LeverageReentrancyGuard.sol";

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
    function initialize(ISiloConfig _config, address _modelConfigAddress) external virtual initializer {
        __ReentrancyGuard_init();
        __LeverageReentrancyGuard_init();

        config = _config;

        (ISiloConfig.SmallConfigData memory configData, address siloAsset) =
            _config.getSmallConfigWithAsset(address(this));

        if (configData.token0 == siloAsset) {
            IInterestRateModel(configData.interestRateModel0).connect(siloAsset, _modelConfigAddress);
        } else {
            IInterestRateModel(configData.interestRateModel1).connect(siloAsset, _modelConfigAddress);
        }
    }

    function siloId() external view virtual returns (uint256) {
        return config.SILO_ID();
    }

    function utilizationData(address _asset) external view returns (UtilizationData memory) {
        return UtilizationData({
            collateralAssets: assetStorage[_asset].collateralAssets,
            debtAssets: assetStorage[_asset].debtAssets,
            interestRateTimestamp: assetStorage[_asset].interestRateTimestamp
        });
    }

    function isSolvent(address _borrower) external view virtual returns (bool) {
        // solhint-disable-line ordering
        return SiloSolvencyLib.isSolventWithInterestAccrue(config, _borrower);
    }

    function depositPossible(address _depositor) external view virtual returns (bool) {
        (ISiloConfig.ConfigData memory configData, address siloAsset) = config.getConfigWithAsset(address(this));
        return SiloERC4626Lib.depositPossible(configData, siloAsset, _depositor);
    }

    function borrowPossible(address _borrower) external view virtual returns (bool) {
        (ISiloConfig.ConfigData memory configData, address siloAsset) = config.getConfigWithAsset(address(this));
        return SiloLendingLib.borrowPossible(configData, siloAsset, _borrower);
    }

    function getMaxLtv() external view virtual returns (uint256) {
        return SiloSolvencyLib.getMaxLtv(config);
    }

    function getLt() external view virtual returns (uint256) {
        return SiloSolvencyLib.getLt(config);
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

    // ERC4626

    function asset() external view virtual returns (address assetTokenAddress) {
        return config.getAssetForSilo(address(this));
    }

    function totalAssets() external view virtual returns (uint256 totalManagedAssets) {
        (ISiloConfig.ConfigData memory configData, address siloAsset) = config.getConfigWithAsset(address(this));

        return SiloStdLib.amountWithInterest(
            siloAsset, assetStorage[siloAsset].collateralAssets, SiloStdLib.findModel(configData, siloAsset)
        );
    }

    function convertToShares(uint256 _assets) external view virtual returns (uint256 shares) {
        (ISiloConfig.ConfigData memory configData, address siloAsset) = config.getConfigWithAsset(address(this));

        (uint256 totalAssetsUpdated, uint256 totalShares) = SiloStdLib.getTotalAssetsAndTotalShares(
            configData, siloAsset, SiloStdLib.AssetType.Collateral, assetStorage
        );

        return SiloERC4626Lib.convertToShares(_assets, totalAssetsUpdated, totalShares, MathUpgradeable.Rounding.Down);
    }

    function convertToAssets(uint256 _shares) external view virtual returns (uint256 assets) {
        (ISiloConfig.ConfigData memory configData, address siloAsset) = config.getConfigWithAsset(address(this));

        (uint256 totalAssetsUpdated, uint256 totalShares) = SiloStdLib.getTotalAssetsAndTotalShares(
            configData, siloAsset, SiloStdLib.AssetType.Collateral, assetStorage
        );

        return SiloERC4626Lib.convertToAssets(_shares, totalAssetsUpdated, totalShares, MathUpgradeable.Rounding.Down);
    }

    function maxDeposit(address _receiver) external view virtual returns (uint256 maxAssets) {
        return SiloERC4626Lib.maxDeposit(config, _receiver);
    }

    function previewDeposit(uint256 _assets) external view virtual returns (uint256 shares) {
        return SiloERC4626Lib.previewDeposit(config, _assets, Protected.No, assetStorage);
    }

    function deposit(uint256 _assets, address _receiver) external virtual nonReentrant returns (uint256 shares) {
        /// @dev avoid magic number 0
        uint256 depositShares = 0;

        (, shares) = _deposit(_assets, depositShares, _receiver, Protected.No);
    }

    function maxMint(address _receiver) external view virtual returns (uint256 maxShares) {
        return SiloERC4626Lib.maxMint(config, _receiver);
    }

    function previewMint(uint256 _shares) external view virtual returns (uint256 assets) {
        return SiloERC4626Lib.previewMint(config, _shares, Protected.No, assetStorage);
    }

    function mint(uint256 _shares, address _receiver) external virtual nonReentrant returns (uint256 assets) {
        /// @dev avoid magic number 0
        uint256 mintAssets = 0;

        (assets,) = _deposit(mintAssets, _shares, _receiver, Protected.No);
    }

    function maxWithdraw(address _owner) external view virtual returns (uint256 maxAssets) {
        (maxAssets,) = SiloERC4626Lib.maxWithdraw(config, _owner, Protected.No, assetStorage);
    }

    function previewWithdraw(uint256 _assets) external view virtual returns (uint256 shares) {
        return SiloERC4626Lib.previewWithdraw(config, _assets, Protected.No, assetStorage);
    }

    function withdraw(uint256 _assets, address _receiver, address _owner)
        external
        virtual
        nonReentrant
        leverageNonReentrant
        returns (uint256 shares)
    {
        /// @dev avoid magic number 0
        uint256 withdrawShares = 0;

        (, shares) = _withdraw(WithdrawParams(_assets, withdrawShares, _receiver, _owner, Protected.No));
    }

    function maxRedeem(address _owner) external view virtual returns (uint256 maxShares) {
        (, maxShares) = SiloERC4626Lib.maxWithdraw(config, _owner, Protected.No, assetStorage);
    }

    function previewRedeem(uint256 _shares) external view virtual returns (uint256 assets) {
        return SiloERC4626Lib.previewRedeem(config, _shares, Protected.No, assetStorage);
    }

    function redeem(uint256 _shares, address _receiver, address _owner)
        external
        virtual
        nonReentrant
        leverageNonReentrant
        returns (uint256 assets)
    {
        /// @dev avoid magic number 0
        uint256 redeemAssets = 0;

        (assets,) = _withdraw(WithdrawParams(redeemAssets, _shares, _receiver, _owner, Protected.No));
    }

    // Protected

    function convertToShares(uint256 _assets, Protected _isProtected)
        external
        view
        virtual
        returns (uint256 shares)
    {
        (ISiloConfig.ConfigData memory configData, address siloAsset) = config.getConfigWithAsset(address(this));

        SiloStdLib.AssetType assetType = SiloStdLib.AssetType.Collateral;
        if (_isProtected == Protected.Yes) assetType = SiloStdLib.AssetType.Protected;

        (uint256 totalAssetsUpdated, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalShares(configData, siloAsset, assetType, assetStorage);

        return SiloERC4626Lib.convertToShares(_assets, totalAssetsUpdated, totalShares, MathUpgradeable.Rounding.Down);
    }

    function convertToAssets(uint256 _shares, Protected _isProtected)
        external
        view
        virtual
        returns (uint256 assets)
    {
        (ISiloConfig.ConfigData memory configData, address siloAsset) = config.getConfigWithAsset(address(this));

        SiloStdLib.AssetType assetType = SiloStdLib.AssetType.Collateral;
        if (_isProtected == Protected.Yes) assetType = SiloStdLib.AssetType.Protected;

        (uint256 totalAssetsUpdated, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalShares(configData, siloAsset, assetType, assetStorage);

        return SiloERC4626Lib.convertToAssets(_shares, totalAssetsUpdated, totalShares, MathUpgradeable.Rounding.Down);
    }

    function maxDeposit(address _receiver, Protected /*_isProtected*/ )
        external
        view
        virtual
        returns (uint256 maxAssets)
    {
        return SiloERC4626Lib.maxDeposit(config, _receiver);
    }

    function previewDeposit(uint256 _assets, Protected _isProtected) external view virtual returns (uint256 shares) {
        return SiloERC4626Lib.previewDeposit(config, _assets, _isProtected, assetStorage);
    }

    function deposit(uint256 _assets, address _receiver, Protected _isProtected)
        external
        virtual
        nonReentrant
        returns (uint256 shares)
    {
        /// @dev avoid magic number 0
        uint256 depositShares = 0;

        (, shares) = _deposit(_assets, depositShares, _receiver, _isProtected);
    }

    function maxMint(address _receiver, Protected /*_isProtected*/ )
        external
        view
        virtual
        returns (uint256 maxShares)
    {
        return SiloERC4626Lib.maxMint(config, _receiver);
    }

    function previewMint(uint256 _shares, Protected _isProtected) external view virtual returns (uint256 assets) {
        return SiloERC4626Lib.previewMint(config, _shares, _isProtected, assetStorage);
    }

    function mint(uint256 _shares, address _receiver, Protected _isProtected)
        external
        virtual
        nonReentrant
        returns (uint256 assets)
    {
        /// @dev avoid magic number 0
        uint256 mintAssets = 0;

        (assets,) = _deposit(mintAssets, _shares, _receiver, _isProtected);
    }

    function maxWithdraw(address _owner, Protected _isProtected) external view virtual returns (uint256 maxAssets) {
        (maxAssets,) = SiloERC4626Lib.maxWithdraw(config, _owner, _isProtected, assetStorage);
    }

    function previewWithdraw(uint256 _assets, Protected _isProtected)
        external
        view
        virtual
        returns (uint256 shares)
    {
        return SiloERC4626Lib.previewWithdraw(config, _assets, _isProtected, assetStorage);
    }

    function withdraw(uint256 _assets, address _receiver, address _owner, Protected _isProtected)
        external
        virtual
        nonReentrant
        leverageNonReentrant
        returns (uint256 shares)
    {
        /// @dev avoid magic number 0
        uint256 withdrawShares = 0;

        (, shares) = _withdraw(WithdrawParams(_assets, withdrawShares, _receiver, _owner, _isProtected));
    }

    function maxRedeem(address _owner, Protected _isProtected) external view virtual returns (uint256 maxShares) {
        (, maxShares) = SiloERC4626Lib.maxWithdraw(config, _owner, _isProtected, assetStorage);
    }

    function previewRedeem(uint256 _shares, Protected _isProtected) external view virtual returns (uint256 assets) {
        return SiloERC4626Lib.previewRedeem(config, _shares, _isProtected, assetStorage);
    }

    function redeem(uint256 _shares, address _receiver, address _owner, Protected _isProtected)
        external
        virtual
        nonReentrant
        leverageNonReentrant
        returns (uint256 assets)
    {
        /// @dev avoid magic number 0
        uint256 redeemAssets = 0;

        (assets,) = _withdraw(WithdrawParams(redeemAssets, _shares, _receiver, _owner, _isProtected));
    }

    function transitionCollateralToProtected(uint256 _shares, address _owner)
        external
        virtual
        nonReentrant
        leverageNonReentrant
        returns (uint256 assets)
    {
        (ISiloConfig.ConfigData memory configData, address siloAsset) = config.getConfigWithAsset(address(this));

        SiloLendingLib.accrueInterest(configData, siloAsset, assetStorage);

        uint256 shares;
        uint256 toShares;

        (assets, shares, toShares) = SiloLendingLib.transitionCollateral(
            configData, siloAsset, _shares, _owner, msg.sender, Transition.ToProtected, assetStorage
        );

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
        (ISiloConfig.ConfigData memory configData, address siloAsset) = config.getConfigWithAsset(address(this));

        SiloLendingLib.accrueInterest(configData, siloAsset, assetStorage);

        uint256 shares;
        uint256 toShares;

        (assets, shares, toShares) = SiloLendingLib.transitionCollateral(
            configData, siloAsset, _shares, _owner, msg.sender, Transition.FromProtected, assetStorage
        );

        emit WithdrawProtected(msg.sender, _owner, _owner, assets, shares);
        emit Deposit(msg.sender, _owner, assets, toShares);
    }

    // Lending

    function maxBorrow(address _borrower) external view virtual returns (uint256 maxAssets) {
        (maxAssets,) = SiloLendingLib.maxBorrow(config, _borrower, assetStorage);
    }

    function previewBorrow(uint256 _assets) external view virtual returns (uint256 shares) {
        return SiloLendingLib.previewBorrow(config, _assets, assetStorage);
    }

    function borrow(uint256 _assets, address _receiver, address _borrower)
        external
        virtual
        nonReentrant
        leverageNonReentrant
        returns (uint256 shares)
    {
        /// @dev avoid magic number 0
        uint256 borrowSharesZero = 0;

        (, shares) = _borrow(_assets, borrowSharesZero, _receiver, _borrower);
    }

    function maxBorrowShares(address _borrower) external view virtual returns (uint256 maxShares) {
        (, maxShares) = SiloLendingLib.maxBorrow(config, _borrower, assetStorage);
    }

    function previewBorrowShares(uint256 _shares) external view virtual returns (uint256 assets) {
        return SiloLendingLib.previewBorrowShares(config, _shares, assetStorage);
    }

    function borrowShares(uint256 _shares, address _receiver, address _borrower)
        external
        virtual
        nonReentrant
        leverageNonReentrant
        returns (uint256 assets)
    {
        /// @dev avoid magic number 0
        uint256 borrowAssets = 0;

        (assets,) = _borrow(borrowAssets, _shares, _receiver, _borrower);
    }

    function maxRepay(address _borrower) external view virtual returns (uint256 assets) {
        (assets,) = SiloLendingLib.maxRepay(config, _borrower, assetStorage);
    }

    function previewRepay(uint256 _assets) external view virtual returns (uint256 shares) {
        return SiloLendingLib.previewRepay(config, _assets, assetStorage);
    }

    function repay(uint256 _assets, address _borrower)
        external
        virtual
        nonReentrant
        leverageNonReentrant
        returns (uint256 shares)
    {
        /// @dev avoid magic number 0
        uint256 repaySharesZero = 0;

        (, shares) = _repay(_assets, repaySharesZero, _borrower);
    }

    function maxRepayShares(address _borrower) external view virtual returns (uint256 shares) {
        (, shares) = SiloLendingLib.maxRepay(config, _borrower, assetStorage);
    }

    function previewRepayShares(uint256 _shares) external view virtual returns (uint256 assets) {
        return SiloLendingLib.previewRepayShares(config, _shares, assetStorage);
    }

    function repayShares(uint256 _shares, address _borrower)
        external
        virtual
        nonReentrant
        leverageNonReentrant
        returns (uint256 assets)
    {
        /// @dev avoid magic number 0
        uint256 repayAssets = 0;

        (assets,) = _repay(repayAssets, _shares, _borrower);
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
        /// @dev flashFee will revert for wrong token
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
        (ISiloConfig.ConfigData memory configData, address siloAsset) = config.getConfigWithAsset(address(this));

        if (!SiloLendingLib.borrowPossible(configData, siloAsset, _borrower)) revert BorrowNotPossible();

        SiloLendingLib.accrueInterest(configData, siloAsset, assetStorage);

        uint256 assets;

        /// @dev avoid magic number 0
        uint256 borrowSharesZero = 0;

        (assets, shares) = SiloLendingLib.borrow(
            configData,
            siloAsset,
            _assets,
            borrowSharesZero,
            address(_receiver),
            _borrower,
            msg.sender,
            UseAssets.Yes,
            assetStorage
        );

        emit Borrow(msg.sender, address(_receiver), _borrower, assets, shares);
        emit Leverage();

        /// @dev allow for deposit reentry only to provide collateral
        if (_receiver.onLeverage(msg.sender, _borrower, siloAsset, assets, _data) != LEVERAGE_CALLBACK) {
            revert LeverageFailed();
        }

        if (!SiloSolvencyLib.isBelowMaxLtv(configData, _borrower)) revert ISilo.AboveMaxLtv();
    }

    function liquidate(address _borrower) external virtual {}

    function accrueInterest() external virtual returns (uint256 accruedInterest) {
        (ISiloConfig.ConfigData memory configData, address siloAsset) = config.getConfigWithAsset(address(this));

        accruedInterest = SiloLendingLib.accrueInterest(configData, siloAsset, assetStorage);
    }

    // Admin

    function withdrawFees() external virtual {
        SiloStdLib.withdrawFees(config, factory, assetStorage);
    }

    // Internal

    function _deposit(uint256 _assets, uint256 _shares, address _receiver, Protected _isProtected)
        internal
        virtual
        returns (uint256 assets, uint256 shares)
    {
        ISiloConfig.ConfigData memory configData;
        address siloAsset;

        {
            ISiloConfig.SmallConfigData memory smallConfigData;

            (smallConfigData, siloAsset) = config.getSmallConfigWithAsset(address(this));
            configData = SiloStdLib.smallConfigToConfig(smallConfigData);
        }

        if (!SiloERC4626Lib.depositPossible(configData, siloAsset, _receiver)) revert ISilo.DepositNotPossible();

        SiloLendingLib.accrueInterest(configData, siloAsset, assetStorage);

        (assets, shares) = SiloERC4626Lib.deposit(
            configData,
            siloAsset,
            msg.sender,
            _receiver,
            _assets,
            _shares,
            _isProtected,
            _assets == 0 ? UseAssets.No : UseAssets.Yes,
            assetStorage
        );

        if (_isProtected == Protected.Yes) {
            emit DepositProtected(msg.sender, _receiver, assets, shares);
        } else {
            emit Deposit(msg.sender, _receiver, assets, shares);
        }
    }

    function _withdraw(WithdrawParams memory _params) internal virtual returns (uint256 assets, uint256 shares) {
        (ISiloConfig.ConfigData memory configData, address siloAsset) = config.getConfigWithAsset(address(this));

        SiloLendingLib.accrueInterest(configData, siloAsset, assetStorage);

        (assets, shares) = SiloERC4626Lib.withdraw(
            configData,
            siloAsset,
            _params.assets,
            _params.shares,
            _params.receiver,
            _params.owner,
            msg.sender,
            _params.isProtected,
            _params.assets == 0 ? UseAssets.No : UseAssets.Yes,
            assetStorage
        );

        if (_params.isProtected == Protected.Yes) {
            emit WithdrawProtected(msg.sender, _params.receiver, _params.owner, assets, shares);
        } else {
            emit Withdraw(msg.sender, _params.receiver, _params.owner, assets, shares);
        }

        /// @dev `_params.owner` must be solvent
        if (!SiloSolvencyLib.isSolvent(configData, _params.owner)) revert ISilo.NotSolvent();
    }

    function _borrow(uint256 _assets, uint256 _shares, address _receiver, address _borrower)
        internal
        virtual
        returns (uint256 assets, uint256 shares)
    {
        (ISiloConfig.ConfigData memory configData, address siloAsset) = config.getConfigWithAsset(address(this));

        if (!SiloLendingLib.borrowPossible(configData, siloAsset, _borrower)) revert BorrowNotPossible();

        SiloLendingLib.accrueInterest(configData, siloAsset, assetStorage);

        (assets, shares) = SiloLendingLib.borrow(
            configData, siloAsset, _assets, _shares, _receiver, _borrower, msg.sender, UseAssets.No, assetStorage
        );

        emit Borrow(msg.sender, _receiver, _borrower, assets, shares);

        if (!SiloSolvencyLib.isBelowMaxLtv(configData, _borrower)) revert ISilo.AboveMaxLtv();
    }

    function _repay(uint256 _assets, uint256 _shares, address _borrower)
        internal
        virtual
        returns (uint256 assets, uint256 shares)
    {
        (ISiloConfig.SmallConfigData memory smallConfigData, address siloAsset) =
            config.getSmallConfigWithAsset(address(this));
        ISiloConfig.ConfigData memory configData = SiloStdLib.smallConfigToConfig(smallConfigData);

        SiloLendingLib.accrueInterest(configData, siloAsset, assetStorage);

        (assets, shares) = SiloLendingLib.repay(
            configData, siloAsset, _assets, _shares, _borrower, msg.sender, UseAssets.No, assetStorage
        );

        emit Repay(msg.sender, _borrower, assets, shares);
    }
}
