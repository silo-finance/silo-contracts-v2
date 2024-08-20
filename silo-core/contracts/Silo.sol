// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {ISilo, IERC4626, IERC3156FlashLender} from "./interfaces/ISilo.sol";
import {ISiloOracle} from "./interfaces/ISiloOracle.sol";
import {IShareToken} from "./interfaces/IShareToken.sol";

import {IERC3156FlashBorrower} from "./interfaces/IERC3156FlashBorrower.sol";
import {ISiloConfig} from "./interfaces/ISiloConfig.sol";
import {ISiloFactory} from "./interfaces/ISiloFactory.sol";
import {IInterestRateModel} from "./interfaces/IInterestRateModel.sol";
import {IHookReceiver} from "./interfaces/IHookReceiver.sol";

import {SiloERC4626} from "./utils/SiloERC4626.sol";

import {Actions} from "./lib/Actions.sol";
import {SiloStdLib} from "./lib/SiloStdLib.sol";
import {SiloSolvencyLib} from "./lib/SiloSolvencyLib.sol";
import {SiloLendingLib} from "./lib/SiloLendingLib.sol";
import {SiloERC4626Lib} from "./lib/SiloERC4626Lib.sol";
import {SiloMathLib} from "./lib/SiloMathLib.sol";
import {Rounding} from "./lib/Rounding.sol";
import {Hook} from "./lib/Hook.sol";
import {AssetTypes} from "./lib/AssetTypes.sol";
import {SiloStorageLib} from "./lib/SiloStorageLib.sol";
import {VaultShareTokenLib} from "./lib/VaultShareTokenLib.sol";

// Keep ERC4626 ordering
// solhint-disable ordering

/// @title Silo vault with lending and borrowing functionality
/// @notice Silo is a ERC4626-compatible vault that allows users to deposit collateral and borrow debt. This contract
/// is deployed twice for each asset for two-asset lending markets.
/// Version: 2.0.0
contract Silo is SiloERC4626 {
    using SafeERC20 for IERC20;

    ISiloFactory public immutable factory;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(ISiloFactory _siloFactory) {
        factory = _siloFactory;

        // Set the config to a non-zero value in order to prevent the implementation contract from being initialized
        SiloStorageLib.getSiloStorage().sharedStorage.siloConfig = ISiloConfig(address(this));
    }

    /// @dev Silo is not designed to work with ether, but it can act as a middleware
    /// between any third-party contract and hook receiver. So, this is the responsibility
    /// of the hook receiver developer to handle it if needed.
    receive() external payable {}

    /// @inheritdoc ISilo
    function callOnBehalfOfSilo(address _target, uint256 _value, CallType _callType, bytes calldata _input)
        external
        payable
        returns (bool success, bytes memory result)
    {
        if (msg.sender != address(SiloStorageLib.hookReceiver())) revert OnlyHookReceiver();

        // Silo will not send back any ether leftovers after the call.
        // The hook receiver should request the ether if needed in a separate call.
        if (_callType == CallType.Delegatecall) {
            (success, result) = _target.delegatecall(_input); // solhint-disable-line avoid-low-level-calls
        } else {
            (success, result) = _target.call{value: _value}(_input); // solhint-disable-line avoid-low-level-calls
        }
    }

    /// @inheritdoc ISilo
    function initialize(ISiloConfig _siloConfig, address _modelConfigAddress) external virtual {
        SiloStorage storage $ = SiloStorageLib.getSiloStorage();

        if (address($.sharedStorage.siloConfig) != address(0)) revert SiloInitialized();

        ISiloConfig.ConfigData memory configData = _siloConfig.getConfig(address(this));

        $.sharedStorage.siloConfig = _siloConfig;
        $.sharedStorage.hookReceiver = IHookReceiver(configData.hookReceiver);

        IInterestRateModel(configData.interestRateModel).connect(_modelConfigAddress);
    }

    /// @inheritdoc ISilo
    function updateHooks() external {
        (uint24 hooksBefore, uint24 hooksAfter) = Actions.updateHooks();
        emit HooksUpdated(hooksBefore, hooksAfter);
    }

    /// @inheritdoc ISilo
    function config() external view virtual returns (ISiloConfig siloConfig) {
        siloConfig = SiloStorageLib.siloConfig();
    }

    /// @inheritdoc ISilo
    function utilizationData() external view virtual returns (UtilizationData memory) {
        SiloStorage storage $ = SiloStorageLib.getSiloStorage();

        return UtilizationData({
            collateralAssets: $.total[AssetTypes.COLLATERAL].assets,
            debtAssets: $.total[AssetTypes.DEBT].assets,
            interestRateTimestamp: $.siloData.interestRateTimestamp
        });
    }

    function getLiquidity() external view virtual returns (uint256 liquidity) {
        return SiloLendingLib.getLiquidity(SiloStorageLib.siloConfig());
    }

    /// @inheritdoc ISilo
    function isSolvent(address _borrower) external view virtual returns (bool) {
        (
            ISiloConfig.ConfigData memory collateral,
            ISiloConfig.ConfigData memory debt
        ) = SiloStorageLib.siloConfig().getConfigs(_borrower);

        return SiloSolvencyLib.isSolvent(collateral, debt, _borrower, AccrueInterestInMemory.Yes);
    }

    /// @inheritdoc ISilo
    function getCollateralAssets() external view virtual returns (uint256 totalCollateralAssets) {
        ISiloConfig.ConfigData memory thisSiloConfig = SiloStorageLib.siloConfig().getConfig(address(this));

        totalCollateralAssets = SiloStdLib.getTotalCollateralAssetsWithInterest(
            thisSiloConfig.silo,
            thisSiloConfig.interestRateModel,
            thisSiloConfig.daoFee,
            thisSiloConfig.deployerFee
        );
    }

    /// @inheritdoc ISilo
    function getDebtAssets() external view virtual returns (uint256 totalDebtAssets) {
        ISiloConfig.ConfigData memory thisSiloConfig = SiloStorageLib.siloConfig().getConfig(address(this));

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
        SiloStorage storage $ = SiloStorageLib.getSiloStorage();

        totalCollateralAssets = $.total[AssetTypes.COLLATERAL].assets;
        totalProtectedAssets = $.total[AssetTypes.PROTECTED].assets;
    }

    /// @inheritdoc ISilo
    function getCollateralAndDebtAssets()
        external
        view
        virtual
        returns (uint256 totalCollateralAssets, uint256 totalDebtAssets)
    {
        SiloStorage storage $ = SiloStorageLib.getSiloStorage();

        totalCollateralAssets = $.total[AssetTypes.COLLATERAL].assets;
        totalDebtAssets = $.total[AssetTypes.DEBT].assets;
    }

    // ERC4626

    /// @inheritdoc IERC4626
    function asset() external view virtual returns (address assetTokenAddress) {
        return SiloStorageLib.siloConfig().getAssetForSilo(address(this));
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
        return _callMaxDepositOrMint(SiloStorageLib.getSiloStorage().total[AssetTypes.COLLATERAL].assets);
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
        return _callMaxDepositOrMint(VaultShareTokenLib.totalSupply());
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
        (maxAssets,) = _callMaxWithdraw(SiloStorageLib.siloConfig(), _owner, CollateralType.Collateral);
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
        (, maxShares) = _callMaxWithdraw(SiloStorageLib.siloConfig(), _owner, CollateralType.Collateral);
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
    function maxDeposit(address /* _receiver */, CollateralType _collateralType)
        external
        view
        virtual
        returns (uint256 maxAssets)
    {
        SiloStorage storage $ = SiloStorageLib.getSiloStorage();
        return _callMaxDepositOrMint($.total[uint256(_collateralType)].assets);
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
        (address protectedToken, address collateralToken,) = SiloStorageLib.siloConfig().getShareTokens(address(this));
        address shareToken = _collateralType == CollateralType.Collateral ? collateralToken : protectedToken;

        return _callMaxDepositOrMint(IShareToken(shareToken).totalSupply());
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
        (maxAssets,) = _callMaxWithdraw(SiloStorageLib.siloConfig(), _owner, _collateralType);
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
        (, maxShares) = _callMaxWithdraw(SiloStorageLib.siloConfig(), _owner, _collateralType);
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
        CollateralType _withdrawType
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
                withdrawType: _withdrawType
            })
        );

        if (_withdrawType == CollateralType.Collateral) {
            emit Withdraw(msg.sender, _owner, _owner, assets, _shares);
            emit DepositProtected(msg.sender, _owner, assets, toShares);
        } else {
            emit WithdrawProtected(msg.sender, _owner, _owner, assets, _shares);
            emit Deposit(msg.sender, _owner, assets, toShares);
        }
    }

    /// @inheritdoc ISilo
    function maxBorrow(address _borrower) external view virtual returns (uint256 maxAssets) {
        (maxAssets,) = SiloLendingLib.maxBorrow(SiloStorageLib.siloConfig(), _borrower, false /* same asset */);
    }

    function maxBorrowSameAsset(address _borrower) external view returns (uint256 maxAssets) {
        (maxAssets,) = SiloLendingLib.maxBorrow(SiloStorageLib.siloConfig(), _borrower, true /* same asset */);
    }

    /// @inheritdoc ISilo
    function previewBorrow(uint256 _assets) external view virtual returns (uint256 shares) {
        (uint256 totalSiloAssets, uint256 totalShares) = _getTotalAssetsAndTotalSharesWithInterest(AssetType.Debt);

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
        (
            , shares
        ) = _borrow(_assets, 0 /* shares */, _receiver, _borrower);
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
        (,maxShares) = SiloLendingLib.maxBorrow(SiloStorageLib.siloConfig(), _borrower, false /* same asset */);
    }

    /// @inheritdoc ISilo
    function previewBorrowShares(uint256 _shares) external view virtual returns (uint256 assets) {
        (uint256 totalSiloAssets, uint256 totalShares) = _getTotalAssetsAndTotalSharesWithInterest(AssetType.Debt);

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
        (
            assets,
        ) = _borrow(0 /* assets */, _shares, _receiver, _borrower);
    }

    /// @inheritdoc ISilo
    function maxRepay(address _borrower) external view virtual returns (uint256 assets) {
        ISiloConfig.ConfigData memory configData = SiloStorageLib.siloConfig().getConfig(address(this));
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
        (, shares) = _repay(_assets, 0 /* repaySharesZero */, _borrower, msg.sender);
    }

    /// @inheritdoc ISilo
    function maxRepayShares(address _borrower) external view virtual returns (uint256 shares) {
        ISiloConfig.ConfigData memory configData = SiloStorageLib.siloConfig().getConfig(address(this));
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
        (assets,) = _repay(0 /* zeroAssets */, _shares, _borrower, msg.sender);
    }

    /// @inheritdoc IERC3156FlashLender
    function maxFlashLoan(address _token) external view virtual returns (uint256 maxLoan) {
        maxLoan = _token == SiloStorageLib.siloConfig().getAssetForSilo(address(this))
            ? IERC20(_token).balanceOf(address(this))
            : 0;
    }

    /// @inheritdoc IERC3156FlashLender
    function flashFee(address _token, uint256 _amount) external view virtual returns (uint256 fee) {
        fee = SiloStdLib.flashFee(SiloStorageLib.siloConfig(), _token, _amount);
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
        if (msg.sender != address(SiloStorageLib.siloConfig())) revert OnlySiloConfig();

        _callAccrueInterestForAsset(_interestRateModel, _daoFee, _deployerFee, address(0) /* no other silo */);
    }

    /// @inheritdoc ISilo
    function withdrawFees() external virtual {
        _accrueInterest();
        Actions.withdrawFees(this);
    }

    /// @inheritdoc ISilo
    function total(uint256 _assetType) external view returns (uint256 totalAssetsByType) {
        totalAssetsByType = SiloStorageLib.getSiloStorage().total[_assetType].assets;
    }

    /// @inheritdoc ISilo
    function siloData() external view returns (uint192 daoAndDeployerFees, uint64 interestRateTimestamp) {
        SiloStorage storage $ = SiloStorageLib.getSiloStorage();
        return ($.siloData.daoAndDeployerFees, $.siloData.interestRateTimestamp);
    }

    /// @inheritdoc ISilo
    function sharedStorage()
        external
        view
        returns (
            ISiloConfig siloConfig,
            uint24 hooksBefore,
            uint24 hooksAfter,
            IHookReceiver hookReceiver
        )
    {
        SiloStorage storage $ = SiloStorageLib.getSiloStorage();

        siloConfig = $.sharedStorage.siloConfig;
        hooksBefore = $.sharedStorage.hooksBefore;
        hooksAfter = $.sharedStorage.hooksAfter;
        hookReceiver = $.sharedStorage.hookReceiver;
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
        (assets, shares) = Actions.deposit(_assets, _shares, _receiver, _collateralType);

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

    function _borrow(
        uint256 _assets,
        uint256 _shares,
        address _receiver,
        address _borrower
    )
        internal
        virtual
        returns (uint256 assets, uint256 shares)
    {
        (assets, shares) = Actions.borrow(
            BorrowArgs({
                assets: _assets,
                shares: _shares,
                receiver: _receiver,
                borrower: _borrower
            })
        );

        emit Borrow(msg.sender, _receiver, _borrower, assets, shares);
    }

    function _repay(uint256 _assets, uint256 _shares, address _borrower, address _repayer)
        internal
        virtual
        returns (uint256 assets, uint256 shares)
    {
        (assets, shares) = Actions.repay(_assets, _shares, _borrower, _repayer);

        emit Repay(_repayer, _borrower, assets, shares);
    }

    function _getTotalAssetsAndTotalSharesWithInterest(AssetType _assetType)
        internal
        view
        returns (uint256 assets, uint256 shares)
    {
        ISiloConfig.ConfigData memory configData = SiloStorageLib.siloConfig().getConfig(address(this));
        (assets, shares) = SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(configData, _assetType);
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
        ) = _getTotalAssetsAndTotalSharesWithInterest(assetType);

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

        (uint256 totalSiloAssets, uint256 totalShares) = _getTotalAssetsAndTotalSharesWithInterest(assetType);

        return SiloMathLib.convertToShares(
            _assets, totalSiloAssets, totalShares, Rounding.DEPOSIT_TO_SHARES, assetType
        );
    }

    function _previewRedeem(
        uint256 _shares,
        CollateralType _collateralType
    ) internal view virtual returns (uint256 assets) {
        ISilo.AssetType assetType = AssetType(uint256(_collateralType));

        (uint256 totalSiloAssets, uint256 totalShares) = _getTotalAssetsAndTotalSharesWithInterest(assetType);

        return SiloMathLib.convertToAssets(
            _shares, totalSiloAssets, totalShares, Rounding.WITHDRAW_TO_ASSETS, assetType
        );
    }

    function _previewWithdraw(
        uint256 _assets,
        ISilo.CollateralType _collateralType
    ) internal view virtual returns (uint256 shares) {
        ISilo.AssetType assetType = AssetType(uint256(_collateralType));

        (uint256 totalSiloAssets, uint256 totalShares) = _getTotalAssetsAndTotalSharesWithInterest(assetType);

        return SiloMathLib.convertToShares(
            _assets, totalSiloAssets, totalShares, Rounding.WITHDRAW_TO_SHARES, assetType
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

    function _callMaxWithdraw(ISiloConfig _config, address _owner, ISilo.CollateralType _collateralType)
        internal
        view
        virtual
        returns (uint256 assets, uint256 shares)
    {
        SiloStorage storage $ = SiloStorageLib.getSiloStorage();

        return SiloERC4626Lib.maxWithdraw(
            _config,
            _owner,
            _collateralType,
            // 0 for CollateralType.Collateral because it will be calculated internally
            _collateralType == CollateralType.Protected ? $.total[AssetTypes.PROTECTED].assets : 0
        );
    }

    function _accrueInterest() internal virtual returns (uint256 accruedInterest) {
        ISiloConfig.ConfigData memory cfg = SiloStorageLib.siloConfig().getConfig(address(this));
        accruedInterest = _callAccrueInterestForAsset(cfg.interestRateModel, cfg.daoFee, cfg.deployerFee, address(0));
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

        SiloStorage storage $ = SiloStorageLib.getSiloStorage();

        accruedInterest = SiloLendingLib.accrueInterestForAsset(
            _interestRateModel,
            _daoFee,
            _deployerFee,
            $.siloData,
            $.total[AssetTypes.COLLATERAL],
            $.total[AssetTypes.DEBT]
        );

        if (accruedInterest != 0) emit AccruedInterest(accruedInterest);
    }
}
