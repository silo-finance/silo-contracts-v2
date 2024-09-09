// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {ISilo, IERC4626, IERC3156FlashLender} from "./interfaces/ISilo.sol";
import {IShareToken} from "./interfaces/IShareToken.sol";

import {IERC3156FlashBorrower} from "./interfaces/IERC3156FlashBorrower.sol";
import {ISiloConfig} from "./interfaces/ISiloConfig.sol";
import {ISiloFactory} from "./interfaces/ISiloFactory.sol";

import {ShareCollateralToken} from "./utils/ShareCollateralToken.sol";

import {Actions} from "./lib/Actions.sol";
import {Views} from "./lib/Views.sol";
import {SiloStdLib} from "./lib/SiloStdLib.sol";
import {SiloSolvencyLib} from "./lib/SiloSolvencyLib.sol";
import {SiloLendingLib} from "./lib/SiloLendingLib.sol";
import {SiloERC4626Lib} from "./lib/SiloERC4626Lib.sol";
import {SiloMathLib} from "./lib/SiloMathLib.sol";
import {Rounding} from "./lib/Rounding.sol";
import {Hook} from "./lib/Hook.sol";
import {AssetTypes} from "./lib/AssetTypes.sol";
import {ShareTokenLib} from "./lib/ShareTokenLib.sol";
import {SiloStorageLib} from "./lib/SiloStorageLib.sol";

// Keep ERC4626 ordering
// solhint-disable ordering

/// @title Silo vault with lending and borrowing functionality
/// @notice Silo is a ERC4626-compatible vault that allows users to deposit collateral and borrow debt. This contract
/// is deployed twice for each asset for two-asset lending markets.
/// Version: 2.0.0
contract Silo is ISilo, ShareCollateralToken {
    using SafeERC20 for IERC20;

    ISiloFactory public immutable factory;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(ISiloFactory _siloFactory) {
        factory = _siloFactory;
    }

    /// @dev Silo is not designed to work with ether, but it can act as a middleware
    /// between any third-party contract and hook receiver. So, this is the responsibility
    /// of the hook receiver developer to handle it if needed.
    receive() external payable {}

    function silo() external view virtual override returns (ISilo) {
        return this;
    }

    /// @inheritdoc ISilo
    function callOnBehalfOfSilo(address _target, uint256 _value, CallType _callType, bytes calldata _input)
        external
        virtual
        payable
        returns (bool success, bytes memory result)
    {
        (success, result) = Actions.callOnBehalfOfSilo(_target, _value, _callType, _input);
    }

    /// @inheritdoc ISilo
    function initialize(ISiloConfig _config) external virtual {
        // silo initialization
        address hookReceiver = Actions.initialize(_config);
        // silo (vault) share token intialization
        _shareTokenInitialize(this, hookReceiver, uint24(Hook.COLLATERAL_TOKEN));
    }

    /// @inheritdoc ISilo
    function updateHooks() external {
        (uint24 hooksBefore, uint24 hooksAfter) = Actions.updateHooks();
        emit HooksUpdated(hooksBefore, hooksAfter);
    }

    /// @inheritdoc ISilo
    function config() external view virtual returns (ISiloConfig siloConfig) {
        siloConfig = ShareTokenLib.siloConfig();
    }

    /// @inheritdoc ISilo
    function utilizationData() external view virtual returns (UtilizationData memory) {
        return Views.utilizationData();
    }

    function getLiquidity() external view virtual returns (uint256 liquidity) {
        return SiloLendingLib.getLiquidity(ShareTokenLib.siloConfig());
    }

    /// @inheritdoc ISilo
    function isSolvent(address _borrower) external view virtual returns (bool) {
        return Views.isSolvent(_borrower);
    }

    /// @inheritdoc ISilo
    function getCollateralAssets() external view virtual returns (uint256 totalCollateralAssets) {
        totalCollateralAssets = Views.getCollateralAssets();
    }

    /// @inheritdoc ISilo
    function getDebtAssets() external view virtual returns (uint256 totalDebtAssets) {
        totalDebtAssets = Views.getDebtAssets();
    }

    /// @inheritdoc ISilo
    function getCollateralAndProtectedTotalsStorage()
        external
        view
        virtual
        returns (uint256 totalCollateralAssets, uint256 totalProtectedAssets)
    {
        (totalCollateralAssets, totalProtectedAssets) = Views.getCollateralAndProtectedAssets();
    }

    /// @inheritdoc ISilo
    function getCollateralAndDebtTotalsStorage()
        external
        view
        virtual
        returns (uint256 totalCollateralAssets, uint256 totalDebtAssets)
    {
        (totalCollateralAssets, totalDebtAssets) = Views.getCollateralAndDebtAssets();
    }

    // ERC4626

    /// @inheritdoc IERC4626
    function asset() external view virtual returns (address assetTokenAddress) {
        return ShareTokenLib.siloConfig().getAssetForSilo(address(this));
    }

    /// @inheritdoc IERC4626
    function totalAssets() external view virtual returns (uint256 totalManagedAssets) {
        (totalManagedAssets,) = SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(AssetType.Collateral);
    }

    /// @inheritdoc IERC4626
    /// @dev For protected (non-borrowable) collateral and debt, use:
    /// `convertToShares(uint256 _assets, AssetType _assetType)` with `AssetType.Protected` or `AssetType.Debt`
    function convertToShares(uint256 _assets) external view virtual returns (uint256 shares) {
        (uint256 totalSiloAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(AssetType.Collateral);

        return SiloMathLib.convertToShares(
            _assets, totalSiloAssets, totalShares, Rounding.DEFAULT_TO_SHARES, AssetType.Collateral
        );
    }

    /// @inheritdoc IERC4626
    /// @dev For protected (non-borrowable) collateral and debt, use:
    /// `convertToAssets(uint256 _shares, AssetType _assetType)` with `AssetType.Protected` or `AssetType.Debt`
    function convertToAssets(uint256 _shares) external view virtual returns (uint256 assets) {
        (uint256 totalSiloAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(AssetType.Collateral);

        return SiloMathLib.convertToAssets(
            _shares, totalSiloAssets, totalShares, Rounding.DEFAULT_TO_ASSETS, AssetType.Collateral
        );
    }

    /// @inheritdoc IERC4626
    function maxDeposit(address /* _receiver */) external view virtual returns (uint256 maxAssets) {
        maxAssets = Views.maxDeposit(CollateralType.Collateral);
    }

    /// @inheritdoc IERC4626
    function previewDeposit(uint256 _assets) external view virtual returns (uint256 shares) {
        return _previewDeposit(_assets, CollateralType.Collateral);
    }

    /// @inheritdoc IERC4626
    function deposit(uint256 _assets, address _receiver)
        external
        virtual
        returns (uint256 shares)
    {
        (, shares) = _deposit(_assets, 0 /* shares */, _receiver, CollateralType.Collateral);
    }

    /// @inheritdoc IERC4626
    function maxMint(address /* _receiver */) external view virtual returns (uint256 maxShares) {
        return Views.maxMint(CollateralType.Collateral);
    }

    /// @inheritdoc IERC4626
    function previewMint(uint256 _shares) external view virtual returns (uint256 assets) {
        return _previewMint(_shares, CollateralType.Collateral);
    }

    /// @inheritdoc IERC4626
    function mint(uint256 _shares, address _receiver) external virtual returns (uint256 assets) {
        (assets,) = _deposit(0 /* assets */, _shares, _receiver, CollateralType.Collateral);
    }

    /// @inheritdoc IERC4626
    function maxWithdraw(address _owner) external view virtual returns (uint256 maxAssets) {
        (maxAssets,) = _maxWithdraw(_owner, CollateralType.Collateral);
    }

    /// @inheritdoc IERC4626
    function previewWithdraw(uint256 _assets) external view virtual returns (uint256 shares) {
        return _previewWithdraw(_assets, CollateralType.Collateral);
    }

    /// @inheritdoc IERC4626
    function withdraw(uint256 _assets, address _receiver, address _owner)
        external
        virtual
        returns (uint256 shares)
    {
        (, shares) = _withdraw(_assets, 0 /* shares */, _receiver, _owner, msg.sender, CollateralType.Collateral);
    }

    /// @inheritdoc IERC4626
    function maxRedeem(address _owner) external view virtual returns (uint256 maxShares) {
        (, maxShares) = _maxWithdraw(_owner, CollateralType.Collateral);
    }

    /// @inheritdoc IERC4626
    function previewRedeem(uint256 _shares) external view virtual returns (uint256 assets) {
        return _previewRedeem(_shares, CollateralType.Collateral);
    }

    /// @inheritdoc IERC4626
    function redeem(uint256 _shares, address _receiver, address _owner)
        external
        virtual
        returns (uint256 assets)
    {
        // avoid magic number 0
        uint256 zeroAssets = 0;

        (assets,) = _withdraw(zeroAssets, _shares, _receiver, _owner, msg.sender, CollateralType.Collateral);
    }

    /// @inheritdoc ISilo
    function getSiloStorage()
        external
        view
        returns (
            uint192 daoAndDeployerRevenue,
            uint64 interestRateTimestamp,
            uint256 protectedAssets,
            uint256 collateralAssets,
            uint256 debtAssets
        )
    {
        return Views.getSiloStorage();
    }

    /// @inheritdoc ISilo
    function convertToShares(uint256 _assets, AssetType _assetType) external view virtual returns (uint256 shares) {
        (
            uint256 totalSiloAssets, uint256 totalShares
        ) = SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(_assetType);

        return SiloMathLib.convertToShares(
            _assets, totalSiloAssets, totalShares, Rounding.DEFAULT_TO_SHARES, _assetType
        );
    }

    /// @inheritdoc ISilo
    function convertToAssets(uint256 _shares, AssetType _assetType) external view virtual returns (uint256 assets) {
        (
            uint256 totalSiloAssets, uint256 totalShares
        ) = SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(_assetType);

        return SiloMathLib.convertToAssets(
            _shares,
            totalSiloAssets,
            totalShares,
            _assetType == AssetType.Debt ? Rounding.DEBT_TO_ASSETS : Rounding.DEFAULT_TO_ASSETS,
            _assetType
        );
    }

    /// @inheritdoc ISilo
    function maxDeposit(address /* _receiver */, CollateralType _collateralType)
        external
        view
        virtual
        returns (uint256 maxAssets)
    {
        maxAssets = Views.maxDeposit(_collateralType);
    }

    /// @inheritdoc ISilo
    function previewDeposit(uint256 _assets, CollateralType _collateralType)
        external
        view
        virtual
        returns (uint256 shares)
    {
        return _previewDeposit(_assets, _collateralType);
    }

    /// @inheritdoc ISilo
    function deposit(uint256 _assets, address _receiver, CollateralType _collateralType)
        external
        virtual
        returns (uint256 shares)
    {
        (, shares) = _deposit(_assets, 0, /* shares */ _receiver, _collateralType);
    }

    /// @inheritdoc ISilo
    function maxMint(address /* _receiver */, CollateralType _collateralType)
        external
        view
        virtual
        returns (uint256 maxShares)
    {
        return Views.maxMint(_collateralType);
    }

    /// @inheritdoc ISilo
    function previewMint(uint256 _shares, CollateralType _collateralType)
        external
        view
        virtual
        returns (uint256 assets)
    {
        return _previewMint(_shares, _collateralType);
    }

    /// @inheritdoc ISilo
    function mint(uint256 _shares, address _receiver, CollateralType _collateralType)
        external
        virtual
        returns (uint256 assets)
    {
        (assets,) = _deposit(0 /* assets */, _shares, _receiver, _collateralType);
    }

    /// @inheritdoc ISilo
    function maxWithdraw(address _owner, CollateralType _collateralType)
        external
        view
        virtual
        returns (uint256 maxAssets)
    {
        (maxAssets,) = _maxWithdraw(_owner, _collateralType);
    }

    /// @inheritdoc ISilo
    function previewWithdraw(uint256 _assets, CollateralType _collateralType)
        external
        view
        virtual
        returns (uint256 shares)
    {
        return _previewWithdraw(_assets, _collateralType);
    }

    /// @inheritdoc ISilo
    function withdraw(uint256 _assets, address _receiver, address _owner, CollateralType _collateralType)
        external
        virtual
        returns (uint256 shares)
    {
        (, shares) = _withdraw(_assets, 0 /* shares */, _receiver, _owner, msg.sender, _collateralType);
    }

    /// @inheritdoc ISilo
    function maxRedeem(address _owner, CollateralType _collateralType)
        external
        view
        virtual
        returns (uint256 maxShares)
    {
        (, maxShares) = _maxWithdraw(_owner, _collateralType);
    }

    /// @inheritdoc ISilo
    function previewRedeem(uint256 _shares, CollateralType _collateralType)
        external
        view
        virtual
        returns (uint256 assets)
    {
        return _previewRedeem(_shares, _collateralType);
    }

    /// @inheritdoc ISilo
    function redeem(uint256 _shares, address _receiver, address _owner, CollateralType _collateralType)
        external
        virtual
        returns (uint256 assets)
    {
        (assets,) = _withdraw(0 /* assets */, _shares, _receiver, _owner, msg.sender, _collateralType);
    }

    /// @inheritdoc ISilo
    function transitionCollateral(
        uint256 _shares,
        address _owner,
        CollateralType _transitionFrom
    )
        external
        virtual
        returns (uint256 assets)
    {
        uint256 toShares;

        (assets, toShares) = Actions.transitionCollateral(
            TransitionCollateralArgs({
                shares: _shares,
                owner: _owner,
                transitionFrom: _transitionFrom
            })
        );

        if (_transitionFrom == CollateralType.Collateral) {
            emit Withdraw(msg.sender, _owner, _owner, assets, _shares);
            emit DepositProtected(msg.sender, _owner, assets, toShares);
        } else {
            emit WithdrawProtected(msg.sender, _owner, _owner, assets, _shares);
            emit Deposit(msg.sender, _owner, assets, toShares);
        }
    }

    /// @inheritdoc ISilo
    function maxBorrow(address _borrower) external view virtual returns (uint256 maxAssets) {
        (maxAssets,) = Views.maxBorrow(_borrower, false /* same asset */);
    }

    function maxBorrowSameAsset(address _borrower) external view returns (uint256 maxAssets) {
        (maxAssets,) = Views.maxBorrow(_borrower, true /* same asset */);
    }

    /// @inheritdoc ISilo
    function previewBorrow(uint256 _assets) external view virtual returns (uint256 shares) {
        (
            uint256 totalSiloAssets, uint256 totalShares
        ) = SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(AssetType.Debt);

        return SiloMathLib.convertToShares(
            _assets, totalSiloAssets, totalShares, Rounding.BORROW_TO_SHARES, AssetType.Debt
        );
    }

    function switchCollateralToThisSilo() external virtual {
        Actions.switchCollateralToThisSilo();
        emit CollateralTypeChanged(msg.sender);
    }

    /// @inheritdoc ISilo
    function leverageSameAsset(
        uint256 _depositAssets,
        uint256 _borrowAssets,
        address _borrower,
        CollateralType _collateralType
    )
        external
        virtual
        returns (uint256 depositedShares, uint256 borrowedShares)
    {
        (
            depositedShares, borrowedShares
        ) = Actions.leverageSameAsset(
            ISilo.LeverageSameAssetArgs({
                depositAssets: _depositAssets,
                borrowAssets: _borrowAssets,
                borrower: _borrower,
                collateralType: _collateralType
            })
        );

        emit Borrow(msg.sender, _borrower, _borrower, _borrowAssets, borrowedShares);

        if (_collateralType == CollateralType.Collateral) {
            emit Deposit(msg.sender, _borrower, _depositAssets, depositedShares);
        } else {
            emit DepositProtected(msg.sender, _borrower, _depositAssets, depositedShares);
        }
    }

    /// @inheritdoc ISilo
    function borrow(uint256 _assets, address _receiver, address _borrower)
        external
        virtual
        returns (uint256 shares)
    {
        uint256 assets;

        (assets, shares) = Actions.borrow(
            BorrowArgs({
                assets: _assets,
                shares: 0,
                receiver: _receiver,
                borrower: _borrower
            })
        );

        emit Borrow(msg.sender, _receiver, _borrower, assets, shares);
    }

    /// @inheritdoc ISilo
    function borrowSameAsset(uint256 _assets, address _receiver, address _borrower)
        external
        returns (uint256 shares)
    {
        uint256 assets;

        (assets, shares) = Actions.borrowSameAsset(
            BorrowArgs({
                assets: _assets,
                shares: 0,
                receiver: _receiver,
                borrower: _borrower
            })
        );

        emit Borrow(msg.sender, _receiver, _borrower, assets, shares);
    }

    /// @inheritdoc ISilo
    function maxBorrowShares(address _borrower) external view virtual returns (uint256 maxShares) {
        (,maxShares) = Views.maxBorrow(_borrower, false /* same asset */);
    }

    /// @inheritdoc ISilo
    function previewBorrowShares(uint256 _shares) external view virtual returns (uint256 assets) {
        (
            uint256 totalSiloAssets, uint256 totalShares
        ) = SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(AssetType.Debt);

        return SiloMathLib.convertToAssets(
            _shares, totalSiloAssets, totalShares, Rounding.BORROW_TO_ASSETS, AssetType.Debt
        );
    }

    /// @inheritdoc ISilo
    function borrowShares(uint256 _shares, address _receiver, address _borrower)
        external
        virtual
        returns (uint256 assets)
    {
        uint256 shares;

        (assets, shares) = Actions.borrow(
            BorrowArgs({
                assets: 0,
                shares: _shares,
                receiver: _receiver,
                borrower: _borrower
            })
        );

        emit Borrow(msg.sender, _receiver, _borrower, assets, shares);
    }

    /// @inheritdoc ISilo
    function maxRepay(address _borrower) external view virtual returns (uint256 assets) {
        assets = Views.maxRepay(_borrower);
    }

    /// @inheritdoc ISilo
    function previewRepay(uint256 _assets) external view virtual returns (uint256 shares) {
        (
            uint256 totalSiloAssets, uint256 totalShares
        ) = SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(AssetType.Debt);

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
        uint256 assets;

        (assets, shares) = Actions.repay({
            _assets: _assets,
            _shares: 0,
            _borrower: _borrower,
            _repayer: msg.sender
        });

        emit Repay(msg.sender, _borrower, assets, shares);
    }

    /// @inheritdoc ISilo
    function maxRepayShares(address _borrower) external view virtual returns (uint256 shares) {
        ISiloConfig.ConfigData memory configData = ShareTokenLib.getConfig();
        shares = IShareToken(configData.debtShareToken).balanceOf(_borrower);
    }

    /// @inheritdoc ISilo
    function previewRepayShares(uint256 _shares) external view virtual returns (uint256 assets) {
        (
            uint256 totalSiloAssets, uint256 totalShares
        ) = SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(AssetType.Debt);

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
        uint256 shares;

        (assets, shares) = Actions.repay({
            _assets: 0,
            _shares: _shares,
            _borrower: _borrower,
            _repayer: msg.sender
        });

        emit Repay(msg.sender, _borrower, assets, shares);
    }

    /// @inheritdoc IERC3156FlashLender
    function maxFlashLoan(address _token) external view virtual returns (uint256 maxLoan) {
        maxLoan = _token == ShareTokenLib.siloConfig().getAssetForSilo(address(this))
            ? IERC20(_token).balanceOf(address(this))
            : 0;
    }

    /// @inheritdoc IERC3156FlashLender
    function flashFee(address _token, uint256 _amount) external view virtual returns (uint256 fee) {
        fee = Views.flashFee(_token, _amount);
    }

    /// @inheritdoc IERC3156FlashLender
    function flashLoan(IERC3156FlashBorrower _receiver, address _token, uint256 _amount, bytes calldata _data)
        external
        virtual
        returns (bool success)
    {
        success = Actions.flashLoan(_receiver, _token, _amount, _data);
        if (success) emit FlashLoan(_amount);
    }

    /// @inheritdoc ISilo
    function accrueInterest() external virtual returns (uint256 accruedInterest) {
        accruedInterest = _accrueInterest();
    }

    /// @inheritdoc ISilo
    function accrueInterestForConfig(address _interestRateModel, uint256 _daoFee, uint256 _deployerFee)
        external
        virtual
    {
        if (msg.sender != address(ShareTokenLib.siloConfig())) revert OnlySiloConfig();

        _accrueInterestForAsset(_interestRateModel, _daoFee, _deployerFee);
    }

    /// @inheritdoc ISilo
    function withdrawFees() external virtual {
        _accrueInterest();
        Actions.withdrawFees(this);
    }

    /// @inheritdoc ISilo
    function getTotalAssetsStorage(uint256 _assetType) external view returns (uint256 totalAssetsByType) {
        totalAssetsByType = SiloStorageLib.getSiloStorage().totalAssets[_assetType];
    }

    function _deposit(
        uint256 _assets,
        uint256 _shares,
        address _receiver,
        ISilo.CollateralType _collateralType
    )
        internal
        virtual
        returns (uint256 assets, uint256 shares)
    {
        (
            assets, shares
        ) = Actions.deposit(_assets, _shares, _receiver, _collateralType);

        if (_collateralType == CollateralType.Collateral) {
            emit Deposit(msg.sender, _receiver, assets, shares);
        } else {
            emit DepositProtected(msg.sender, _receiver, assets, shares);
        }
    }

    function _withdraw(
        uint256 _assets,
        uint256 _shares,
        address _receiver,
        address _owner,
        address _spender,
        ISilo.CollateralType _collateralType
    )
        internal
        virtual
        returns (uint256 assets, uint256 shares)
    {
        (assets, shares) = Actions.withdraw(
            WithdrawArgs({
                assets: _assets,
                shares: _shares,
                receiver: _receiver,
                owner: _owner,
                spender: _spender,
                collateralType: _collateralType
            })
        );

        if (_collateralType == CollateralType.Collateral) {
            emit Withdraw(msg.sender, _receiver, _owner, assets, shares);
        } else {
            emit WithdrawProtected(msg.sender, _receiver, _owner, assets, shares);
        }
    }

    function _previewMint(uint256 _shares, CollateralType _collateralType)
        internal
        view
        virtual
        returns (uint256 assets)
    {
        ISilo.AssetType assetType = AssetType(uint256(_collateralType));

        (
            uint256 totalSiloAssets, uint256 totalShares
        ) = SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(assetType);

        return SiloMathLib.convertToAssets(
            _shares, totalSiloAssets, totalShares, Rounding.DEPOSIT_TO_ASSETS, assetType
        );
    }

    function _previewDeposit(uint256 _assets, CollateralType _collateralType)
        internal
        view
        virtual
        returns (uint256 shares)
    {
        ISilo.AssetType assetType = AssetType(uint256(_collateralType));

        (uint256 totalSiloAssets, uint256 totalShares) = SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(assetType);

        return SiloMathLib.convertToShares(
            _assets, totalSiloAssets, totalShares, Rounding.DEPOSIT_TO_SHARES, assetType
        );
    }

    function _previewRedeem(
        uint256 _shares,
        CollateralType _collateralType
    ) internal view virtual returns (uint256 assets) {
        ISilo.AssetType assetType = AssetType(uint256(_collateralType));

        (uint256 totalSiloAssets, uint256 totalShares) = SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(assetType);

        return SiloMathLib.convertToAssets(
            _shares, totalSiloAssets, totalShares, Rounding.WITHDRAW_TO_ASSETS, assetType
        );
    }

    function _previewWithdraw(
        uint256 _assets,
        ISilo.CollateralType _collateralType
    ) internal view virtual returns (uint256 shares) {
        ISilo.AssetType assetType = AssetType(uint256(_collateralType));

        (uint256 totalSiloAssets, uint256 totalShares) = SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(assetType);

        return SiloMathLib.convertToShares(
            _assets, totalSiloAssets, totalShares, Rounding.WITHDRAW_TO_SHARES, assetType
        );
    }

    function _maxWithdraw(address _owner, ISilo.CollateralType _collateralType)
        internal
        view
        virtual
        returns (uint256 assets, uint256 shares)
    {
        return Views.maxWithdraw(_owner, _collateralType);
    }

    function _accrueInterest() internal virtual returns (uint256 accruedInterest) {
        ISiloConfig.ConfigData memory cfg = ShareTokenLib.getConfig();
        accruedInterest = _accrueInterestForAsset(cfg.interestRateModel, cfg.daoFee, cfg.deployerFee);
    }

    function _accrueInterestForAsset(
        address _interestRateModel,
        uint256 _daoFee,
        uint256 _deployerFee
    ) internal virtual returns (uint256 accruedInterest) {
        accruedInterest = Actions.accrueInterestForAsset(_interestRateModel, _daoFee, _deployerFee);
        if (accruedInterest != 0) emit AccruedInterest(accruedInterest);
    }
}
