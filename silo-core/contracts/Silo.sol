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
import {SiloStdLib} from "./lib/SiloStdLib.sol";
import {SiloSolvencyLib} from "./lib/SiloSolvencyLib.sol";
import {SiloLendingLib} from "./lib/SiloLendingLib.sol";
import {SiloERC4626Lib} from "./lib/SiloERC4626Lib.sol";

// solhint-disable ordering

contract Silo is Initializable, ISilo, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    string public constant VERSION = "2.0.0";

    // TODO: set FLASHLOAN_FEE on deployment
    /// @dev 1%, 1e18 == 100%
    uint256 public constant FLASHLOAN_FEE = 0.01e18;
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
    function initialize(ISiloConfig _config) external virtual initializer {
        __ReentrancyGuard_init();

        config = _config;

        // TODO: call connect to model
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
        uint256 assets;

        (assets, shares) = SiloERC4626Lib.deposit(
            config, msg.sender, _receiver, _assets, 0, Protected.No, UseAssets.Yes, assetStorage
        );

        emit Deposit(msg.sender, _receiver, assets, shares);
    }

    function maxMint(address _receiver) external view virtual returns (uint256 maxShares) {
        return SiloERC4626Lib.maxMint(config, _receiver);
    }

    function previewMint(uint256 _shares) external view virtual returns (uint256 assets) {
        return SiloERC4626Lib.previewMint(config, _shares, Protected.No, assetStorage);
    }

    function mint(uint256 _shares, address _receiver) external virtual nonReentrant returns (uint256 assets) {
        uint256 shares;

        (assets, shares) = SiloERC4626Lib.deposit(
            config, msg.sender, _receiver, 0, _shares, Protected.No, UseAssets.No, assetStorage
        );

        emit Deposit(msg.sender, _receiver, assets, shares);
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
        returns (uint256 shares)
    {
        uint256 assets;

        (assets, shares) = SiloERC4626Lib.withdraw(
            config, _assets, 0, _receiver, _owner, msg.sender, Protected.No, UseAssets.Yes, assetStorage
        );

        emit Withdraw(msg.sender, _receiver, _owner, assets, shares);
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
        returns (uint256 assets)
    {
        uint256 shares;

        (assets, shares) = SiloERC4626Lib.withdraw(
            config, 0, _shares, _receiver, _owner, msg.sender, Protected.No, UseAssets.No, assetStorage
        );

        emit Withdraw(msg.sender, _receiver, _owner, assets, shares);
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
        uint256 assets;

        (assets, shares) = SiloERC4626Lib.deposit(
            config, msg.sender, _receiver, _assets, 0, _isProtected, UseAssets.Yes, assetStorage
        );

        if (_isProtected == Protected.Yes) {
            emit DepositProtected(msg.sender, _receiver, assets, shares);
        } else {
            emit Deposit(msg.sender, _receiver, assets, shares);
        }
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
        uint256 shares;

        (assets, shares) = SiloERC4626Lib.deposit(
            config, msg.sender, _receiver, 0, _shares, _isProtected, UseAssets.No, assetStorage
        );

        if (_isProtected == Protected.Yes) {
            emit DepositProtected(msg.sender, _receiver, assets, shares);
        } else {
            emit Deposit(msg.sender, _receiver, assets, shares);
        }
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
        returns (uint256 shares)
    {
        uint256 assets;

        (assets, shares) = SiloERC4626Lib.withdraw(
            config, _assets, 0, _receiver, _owner, msg.sender, _isProtected, UseAssets.Yes, assetStorage
        );

        if (_isProtected == Protected.Yes) {
            emit WithdrawProtected(msg.sender, _receiver, _owner, assets, shares);
        } else {
            emit Withdraw(msg.sender, _receiver, _owner, assets, shares);
        }
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
        returns (uint256 assets)
    {
        uint256 shares;

        (assets, shares) = SiloERC4626Lib.withdraw(
            config, 0, _shares, _receiver, _owner, msg.sender, _isProtected, UseAssets.No, assetStorage
        );

        if (_isProtected == Protected.Yes) {
            emit WithdrawProtected(msg.sender, _receiver, _owner, assets, shares);
        } else {
            emit Withdraw(msg.sender, _receiver, _owner, assets, shares);
        }
    }

    function transitionToProtected(uint256 _shares, address _owner)
        external
        virtual
        nonReentrant
        returns (uint256 assets)
    {
        (ISiloConfig.ConfigData memory configData, address siloAsset) = config.getConfigWithAsset(address(this));

        uint256 shares;
        uint256 toShares;

        (assets, shares, toShares) = SiloLendingLib.transition(
            configData, siloAsset, _shares, _owner, msg.sender, Transition.ToProtected, assetStorage
        );

        emit Withdraw(msg.sender, _owner, _owner, assets, shares);
        emit DepositProtected(msg.sender, _owner, assets, toShares);
    }

    function transitionFromProtected(uint256 _shares, address _owner)
        external
        virtual
        nonReentrant
        returns (uint256 assets)
    {
        (ISiloConfig.ConfigData memory configData, address siloAsset) = config.getConfigWithAsset(address(this));

        uint256 shares;
        uint256 toShares;

        (assets, shares, toShares) = SiloLendingLib.transition(
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
        returns (uint256 shares)
    {
        (ISiloConfig.ConfigData memory configData, address siloAsset) = config.getConfigWithAsset(address(this));

        uint256 assets;

        (assets, shares) = SiloLendingLib.borrow(
            configData,
            siloAsset,
            _assets,
            0,
            _receiver,
            _borrower,
            msg.sender,
            UseAssets.Yes,
            CheckSolvency.Yes,
            assetStorage
        );

        emit Borrow(msg.sender, _receiver, _borrower, assets, shares);
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
        returns (uint256 assets)
    {
        (ISiloConfig.ConfigData memory configData, address siloAsset) = config.getConfigWithAsset(address(this));

        uint256 shares;

        (assets, shares) = SiloLendingLib.borrow(
            configData,
            siloAsset,
            0,
            _shares,
            _receiver,
            _borrower,
            msg.sender,
            UseAssets.No,
            CheckSolvency.Yes,
            assetStorage
        );

        emit Borrow(msg.sender, _receiver, _borrower, assets, shares);
    }

    function maxRepay(address _borrower) external view virtual returns (uint256 assets) {
        (assets,) = SiloLendingLib.maxRepay(config, _borrower, assetStorage);
    }

    function previewRepay(uint256 _assets) external view virtual returns (uint256 shares) {
        return SiloLendingLib.previewRepay(config, _assets, assetStorage);
    }

    function repay(uint256 _assets, address _borrower) external virtual nonReentrant returns (uint256 shares) {
        uint256 assets;

        (assets, shares) =
            SiloLendingLib.repay(config, _assets, 0, _borrower, msg.sender, UseAssets.Yes, assetStorage);

        emit Repay(msg.sender, _borrower, assets, shares);
    }

    function maxRepayShares(address _borrower) external view virtual returns (uint256 shares) {
        (, shares) = SiloLendingLib.maxRepay(config, _borrower, assetStorage);
    }

    function previewRepayShares(uint256 _shares) external view virtual returns (uint256 assets) {
        return SiloLendingLib.previewRepayShares(config, _shares, assetStorage);
    }

    function repayShares(uint256 _shares, address _borrower) external virtual nonReentrant returns (uint256 assets) {
        uint256 shares;

        (assets, shares) = SiloLendingLib.repay(config, 0, _shares, _borrower, msg.sender, UseAssets.No, assetStorage);

        emit Repay(msg.sender, _borrower, assets, shares);
    }

    function maxFlashLoan(address _token) external view returns (uint256) {
        return
            _token == config.getAssetForSilo(address(this)) ? IERC20Upgradeable(_token).balanceOf(address(this)) : 0;
    }

    function flashFee(address _token, uint256 _amount) external view returns (uint256) {
        return SiloStdLib.flashFee(config, FLASHLOAN_FEE, _token, _amount);
    }

    function flashLoan(IERC3156FlashBorrower _receiver, address _token, uint256 _amount, bytes calldata _data)
        external
        returns (bool)
    {
        /// @dev flashFee will revert for wrong token
        uint256 fee = SiloStdLib.flashFee(config, FLASHLOAN_FEE, _token, _amount);

        IERC20Upgradeable(_token).safeTransferFrom(address(this), address(_receiver), _amount);

        if (_receiver.onFlashLoan(msg.sender, _token, _amount, fee, _data) != FLASHLOAN_CALLBACK) {
            revert FlashloanFailed();
        }

        IERC20Upgradeable(_token).safeTransferFrom(address(_receiver), address(this), _amount + fee);

        assetStorage[_token].daoAndDeployerFees += fee;

        return true;
    }

    function leverage(uint256 _assets, ILeverageBorrower _receiver, address _borrower, bytes calldata _data)
        external
        virtual
        returns (uint256 shares)
    {
        (ISiloConfig.ConfigData memory configData, address siloAsset) = config.getConfigWithAsset(address(this));

        uint256 assets;

        (assets, shares) = SiloLendingLib.borrow(
            configData,
            siloAsset,
            _assets,
            0,
            address(_receiver),
            _borrower,
            msg.sender,
            UseAssets.Yes,
            CheckSolvency.No,
            assetStorage
        );

        if (_receiver.onLeverage(msg.sender, _borrower, siloAsset, _assets, _data) != LEVERAGE_CALLBACK) {
            revert LeverageFailed();
        }

        /// @dev Deposit event should be emitted during callback so now it's time for `Borrow`
        emit Borrow(msg.sender, address(_receiver), _borrower, assets, shares);

        /// @dev `borrow` did not check solvency to allow borrower to deposit collateral during callback
        ///      so we must check it now. `_borrower` must be below maxLtv
        (uint256 ltv, bool isToken0Collateral) = SiloSolvencyLib.getLtv(configData, _borrower);
        uint256 maxLTV = isToken0Collateral ? configData.maxLtv0 : configData.maxLtv1;

        if (ltv > maxLTV) revert ISilo.NotSolvent();
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
}
