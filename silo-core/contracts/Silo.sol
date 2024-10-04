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

    // TODO: add nat spec to say that this is required by share token interface
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

    // TODO: certora rule updateHooks() should call all share tokens to update their hooks
    // TODO: certora rule after a call to updateHooks() all share tokens and silo should have the same values for hooksBefore and hooksAfter
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

    // TODO: add natspec and explain what "liquidity" is. And explain that interest is included in the liquidity.
    function getLiquidity() external view virtual returns (uint256 liquidity) {
        return SiloLendingLib.getLiquidity(ShareTokenLib.siloConfig());
    }

    // TODO: certora rule if user has no debt, should always be solvent and ltv == 0
    // TODO: certora rule if user has debt and no collateral (bad debt), should always be insolvent
    /// @inheritdoc ISilo
    function isSolvent(address _borrower) external view virtual returns (bool) {
        return Views.isSolvent(_borrower);
    }

    // TODO: certora rule getCollateralAssets() == totalAssets[AssetTypes.COLLATERAL] for the same block
    // TODO: certora rule getCollateralAssets() > totalAssets[AssetTypes.COLLATERAL] with pending interest
    /// @inheritdoc ISilo
    function getCollateralAssets() external view virtual returns (uint256 totalCollateralAssets) {
        // TODO: replace with totalAssets() implementation
        totalCollateralAssets = Views.getCollateralAssets();
    }

    // TODO: certora rule getDebtAssets() == totalAssets[AssetTypes.DEBT] for the same block
    // TODO: certora rule getDebtAssets() > totalAssets[AssetTypes.DEBT] with pending interest
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

    // TODO: certora rule totalAssets() == getCollateralAssets() always
    /// @inheritdoc IERC4626
    function totalAssets() external view virtual returns (uint256 totalManagedAssets) {
        (totalManagedAssets,) = SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(AssetType.Collateral);
    }

    // TODO: certora rule return value of convertToShares() == previewDeposit() == deposit() should always be the same
    /// @inheritdoc IERC4626
    /// @dev For protected (non-borrowable) collateral and debt, use:
    /// `convertToShares(uint256 _assets, AssetType _assetType)` with `AssetType.Protected` or `AssetType.Debt`
    function convertToShares(uint256 _assets) external view virtual returns (uint256 shares) {
        (uint256 totalSiloAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(AssetType.Collateral);

        // TODO: make sure rounding follows previewDeposit. Remove Rounding.DEFAULT_TO_SHARES
        return SiloMathLib.convertToShares(
            _assets, totalSiloAssets, totalShares, Rounding.DEFAULT_TO_SHARES, AssetType.Collateral
        );
    }

    // TODO: certora rule return value of convertToAssets() == previewMint() == mint() should always be the same
    // TODO: review all unchecked math operations
    // TODO: do we follow check effects interactions pattern? Oracles calls and before quote calls etc.
    // TODO: check how msg.sender is used in the contracts
    // TODO: follow user inputs and which data can be manipulated by the user
    /// @inheritdoc IERC4626
    /// @dev For protected (non-borrowable) collateral and debt, use:
    /// `convertToAssets(uint256 _shares, AssetType _assetType)` with `AssetType.Protected` or `AssetType.Debt`
    function convertToAssets(uint256 _shares) external view virtual returns (uint256 assets) {
        (uint256 totalSiloAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(AssetType.Collateral);

        // TODO: make sure rounding follows previewMint, Rounding.DEFAULT_TO_ASSETS
        return SiloMathLib.convertToAssets(
            _shares, totalSiloAssets, totalShares, Rounding.DEFAULT_TO_ASSETS, AssetType.Collateral
        );
    }

    /// @inheritdoc IERC4626
    function maxDeposit(address /* _receiver */) external pure virtual returns (uint256 maxAssets) {
        // TODO: replace maxDeposit with constant
        maxAssets = Views.maxDeposit();
    }

    /// @inheritdoc IERC4626
    function previewDeposit(uint256 _assets) external view virtual returns (uint256 shares) {
        return _previewDeposit(_assets, CollateralType.Collateral);
    }

    // TODO: certora rule deposit/mint always increase value on any sstore operation
    // TODO: certora rule collateral share token balance always increase after deposit/mint only for receiver
    // TODO: certora rule deposit/mint/withdraw/redeem/borrow/borrowShares/repay/repayShares/borrowSameAsset/leverageSameAsset should always call turnOnReentrancyProtection(), turnOffReentrancyProtection()
    // TODO: certora rule deposit/mint/repay/repayShares/borrowSameAsset/leverageSameAsset should always call accrueInterest() on one (called) Silo
    // TODO: certora rule withdraw/redeem/borrow/borrowShares should always call accrueInterest() on both Silos
    // TODO: certora rule deposit/mint/withdraw/redeem/borrow/borrowShares/repay/repayShares/borrowSameAsset/leverageSameAsset should call hookBefore(), hookAfter() - if configured
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
        return Views.maxMint();
    }

    // TODO: certora rule result of previewMint() should be equal to result of mint()
    /// @inheritdoc IERC4626
    function previewMint(uint256 _shares) external view virtual returns (uint256 assets) {
        return _previewMint(_shares, CollateralType.Collateral);
    }

    // TODO: certora rule apply rules from deposit()
    /// @inheritdoc IERC4626
    function mint(uint256 _shares, address _receiver) external virtual returns (uint256 assets) {
        (assets,) = _deposit(0 /* assets */, _shares, _receiver, CollateralType.Collateral);
    }

    // TODO: certora rule result of maxWithdraw() should never be more than liquidity of the Silo
    // TODO: certora rule result of maxWithdraw() used as input to withdraw() should never revert
    // TODO: certora rule if user has no debt and liquidity is available, shareToken.balanceOf(user) used as input to redeem(), assets from redeem() should be equal to maxWithdraw()
    /// @inheritdoc IERC4626
    function maxWithdraw(address _owner) external view virtual returns (uint256 maxAssets) {
        (maxAssets,) = _maxWithdraw(_owner, CollateralType.Collateral);
    }

    // TODO: certora rule 
    /// @inheritdoc IERC4626 result of previewWithdraw() should never equal to result of withdraw()
    function previewWithdraw(uint256 _assets) external view virtual returns (uint256 shares) {
        return _previewWithdraw(_assets, CollateralType.Collateral);
    }

    // TODO: certora rule withdraw() should never revert if liquidity for a user and a silo is sufficient even if oracle reverts
    // TODO: certora rule withdraw() user is always solvent after withdraw()
    /// @inheritdoc IERC4626
    function withdraw(uint256 _assets, address _receiver, address _owner)
        external
        virtual
        returns (uint256 shares)
    {
        // TODO: make params named, apply globally, use your best judgement
        (, shares) = _withdraw(_assets, 0 /* shares */, _receiver, _owner, msg.sender, CollateralType.Collateral);
    }

    // TODO: certora rule result of maxRedeem() used as input to redeem() should never revert
    // TODO: certora rule result of maxRedeem() should never be more than share token balanceOf user
    // TODO: certora rule if user has no debt and liquidity is available, maxRedeem() output equals shareToken.balanceOf(user)
    /// @inheritdoc IERC4626
    function maxRedeem(address _owner) external view virtual returns (uint256 maxShares) {
        (, maxShares) = _maxWithdraw(_owner, CollateralType.Collateral);
    }

    // TODO: certora rule return value from previewRedeem() should be equal to redeem()
    /// @inheritdoc IERC4626
    function previewRedeem(uint256 _shares) external view virtual returns (uint256 assets) {
        return _previewRedeem(_shares, CollateralType.Collateral);
    }

    // TODO: certora rule apply everything from withdraw()
    /// @inheritdoc IERC4626
    function redeem(uint256 _shares, address _receiver, address _owner)
        external
        virtual
        returns (uint256 assets)
    {
        // avoid magic number 0
        uint256 zeroAssets = 0;

        // TODO: make params named, apply globally, use your best judgement
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

        // TODO: make sure rounding follows previewDeposit. Remove Rounding.DEFAULT_TO_SHARES
        // TODO: make sure rounding for debt follows previewBorrow
        return SiloMathLib.convertToShares(
            _assets, totalSiloAssets, totalShares, Rounding.DEFAULT_TO_SHARES, _assetType
        );
    }

    /// @inheritdoc ISilo
    function convertToAssets(uint256 _shares, AssetType _assetType) external view virtual returns (uint256 assets) {
        (
            uint256 totalSiloAssets, uint256 totalShares
        ) = SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(_assetType);

        // TODO: make sure rounding follows previewMint, Rounding.DEFAULT_TO_ASSETS
        // TODO: make sure rounding for debt follows previewBorrowShares
        return SiloMathLib.convertToAssets(
            _shares,
            totalSiloAssets,
            totalShares,
            _assetType == AssetType.Debt ? Rounding.DEBT_TO_ASSETS : Rounding.DEFAULT_TO_ASSETS,
            _assetType
        );
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
        // TODO: make params named, apply globally, use your best judgement
        (, shares) = _deposit(_assets, 0, /* shares */ _receiver, _collateralType);
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

    // TODO: certora rule withdraw() and deposit() should be equal to transitionCollateral() - state changes should be the same
    // TODO: certora rule if user is solvent transitionCollateral() for `_transitionFrom` == CollateralType.Protected should never revert
    // TODO: certora rule if user is NOT solvent transitionCollateral() always reverts
    // TODO: certora rule transitionCollateral() for `_transitionFrom` == CollateralType.Collateral should revert if not enough liquidity is available
    // TODO: certora rule during transitionCollateral share tokens balances should change only for the same address (owner)
    // TODO: certora rule transitionCollateral should not change underlying assets balance
    // TODO: certora rule transitionCollateral should not increase users assets
    // TODO: certora rule transitionCollateral should not decrease user assets by more than rounding error
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

    // TODO: certora rule when user borrows maxAssets returned by maxBorrow, borrow should not revert
    // TODO: up to 2 wei underestimation should be removed from natspec
    /// @inheritdoc ISilo
    function maxBorrow(address _borrower) external view virtual returns (uint256 maxAssets) {
        // TODO: use named params
        (maxAssets,) = Views.maxBorrow(_borrower, false /* same asset */);
    }

    // TODO: change order of functions to match ERC4626
    // maxBorrow
    // previewBorrow
    // borrow
    // maxBorrowShares
    // previewBorrowShares
    // borrowShares
    // maxBorrowSameAsset
    // borrowSameAsset
    // leverageSameAsset

    // TODO: certora rule returned value from maxBorrowSameAsset() used for borrowSameAsset() never reverts
    function maxBorrowSameAsset(address _borrower) external view returns (uint256 maxAssets) {
        // TODO: use named params
        (maxAssets,) = Views.maxBorrow(_borrower, true /* same asset */);
    }

    // TODO: certora rule return value of previewBorrow() should be always equal to borrow()
    /// @inheritdoc ISilo
    function previewBorrow(uint256 _assets) external view virtual returns (uint256 shares) {
        (
            uint256 totalSiloAssets, uint256 totalShares
        ) = SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(AssetType.Debt);

        return SiloMathLib.convertToShares(
            _assets, totalSiloAssets, totalShares, Rounding.BORROW_TO_SHARES, AssetType.Debt
        );
    }

    // TODO: certora rule user must be solvent after switchCollateralToThisSilo()
    // TODO: certora rule borrowerCollateralSilo[user] should be set to "this" Silo address. No other state should be changed in either Silo.
    // TODO: add natspec
    function switchCollateralToThisSilo() external virtual {
        Actions.switchCollateralToThisSilo();
        emit CollateralTypeChanged(msg.sender);
    }

    // TODO: certora rule if leverageSameAsset() should never decrease Silo asset balance
    // TODO: certora rule if maxLtv < 100% then leverageSameAsset() should always increase Silo asset balance
    // TODO: certora rule leverageSameAsset(x, y) should be always change state equivalent to deposit(x) and borrow(y)
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

    // TODO: certora rule apply all rules from borrowShares()
    // TODO: certora rule borrow() should decrease Silo balance by exactly `_assets`
    // TODO: certora rule everybody can exit Silo meaning: calling borrow(), then repay(), all users should be able to withdraw() all funds and withdrawFess() withdraws all fees successfully
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

    // TODO: certora rule apply all rules from borrow()
    // TODO: add more details to natspec
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
        // TODO: use named params
        (,maxShares) = Views.maxBorrow(_borrower, false /* same asset */);
    }

    // TODO: certora rule return value of previewBorrowShares() always equals borrowShares()
    /// @inheritdoc ISilo
    function previewBorrowShares(uint256 _shares) external view virtual returns (uint256 assets) {
        (
            uint256 totalSiloAssets, uint256 totalShares
        ) = SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(AssetType.Debt);

        return SiloMathLib.convertToAssets(
            _shares, totalSiloAssets, totalShares, Rounding.BORROW_TO_ASSETS, AssetType.Debt
        );
    }

    // TODO: certora rule borrowShares() should never decrease totalAssets[AssetType.Collateral]
    // TODO: certora rule borrowShares() should never change totalAssets[AssetType.Protected] and balances of protected and collateral share tokens and total supply for each
    // TODO: certora rule user should always have ltv below maxLTV after successful call to borrowShares()
    // TODO: certora rule borrowShares() should always increase debt shares of the borrower
    // TODO: certora rule borrowShares() should always increase balance of the receiver
    // TODO: certora rule inverse rules should make sure that difference between before and after values are within rounding error ie. HLP_borrowSharesAndInverse
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

    // TODO: certora rule maxRepay() should never return more than totalAssets[AssetType.Debt]
    // TODO: certora rule user that can repay, calling repay() with maxRepay() result should never revert 
    // TODO: certora rule repay() should not be able to repay more than maxRepay()
    // TODO: certora rule repaying with maxRepay() value should burn all user share debt token balance 
    /// @inheritdoc ISilo
    function maxRepay(address _borrower) external view virtual returns (uint256 assets) {
        assets = Views.maxRepay(_borrower);
    }

    // TODO: certora rule return value of previewRepay() should be always equal to repay()
    /// @inheritdoc ISilo
    function previewRepay(uint256 _assets) external view virtual returns (uint256 shares) {
        (
            uint256 totalSiloAssets, uint256 totalShares
        ) = SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(AssetType.Debt);

        return SiloMathLib.convertToShares(
            _assets, totalSiloAssets, totalShares, Rounding.REPAY_TO_SHARES, AssetType.Debt
        );
    }

    // TODO: certora rule any user that can repay the debt should be able to repay the debt
    // TODO: certora rule repay() any other user than borrower can repay
    // TODO: certora rule repay() user can't over repay
    // TODO: certora rule repay() if user repay all debt, no extra debt should be created
    // TODO: certora rule repay() should decrease the debt
    // TODO: certora rule repay() should reduce only the debt of the borrower
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
        // TODO: get debtShareToken using getDebtShareTokenAndAsset
        ISiloConfig.ConfigData memory configData = ShareTokenLib.getConfig();
        shares = IShareToken(configData.debtShareToken).balanceOf(_borrower);
    }

    // TODO: certora rule return value of previewRepayShares() should be always equal to repayShares()
    /// @inheritdoc ISilo
    function previewRepayShares(uint256 _shares) external view virtual returns (uint256 assets) {
        (
            uint256 totalSiloAssets, uint256 totalShares
        ) = SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(AssetType.Debt);

        return SiloMathLib.convertToAssets(
            _shares, totalSiloAssets, totalShares, Rounding.REPAY_TO_ASSETS, AssetType.Debt
        );
    }

    // TODO: certora rule apply all repay() rules
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

    // TODO: certora rule maxFlashLoan() should return the same value before and after deposit/withdraw of protected assets and withdrawFees()
    /// @inheritdoc IERC3156FlashLender
    function maxFlashLoan(address _token) external view virtual returns (uint256 maxLoan) {
        // TODO: it should exclude protected assets
        maxLoan = _token == ShareTokenLib.siloConfig().getAssetForSilo(address(this))
            ? IERC20(_token).balanceOf(address(this))
            : 0;
    }

    // TODO: certora rule flashFee() returns non-zero value if fee is set to non-zero value
    /// @inheritdoc IERC3156FlashLender
    function flashFee(address _token, uint256 _amount) external view virtual returns (uint256 fee) {
        fee = Views.flashFee(_token, _amount);
    }

    // TODO: certora rule flashLoan() should never change any storage except increasing daoAndDeployerRevenue if flashloanFee is non-zero
    // TODO: certora rule flashLoan() daoAndDeployerRevenue and Silo asset balance should increase by flashFee()
    /// @inheritdoc IERC3156FlashLender
    function flashLoan(IERC3156FlashBorrower _receiver, address _token, uint256 _amount, bytes calldata _data)
        external
        virtual
        returns (bool success)
    {
        success = Actions.flashLoan(_receiver, _token, _amount, _data);
        if (success) emit FlashLoan(_amount);
    }

    // TODO: certora rule accrueInterest() should never revert
    // TODO: certora rule accrueInterest() calling twice is the same as calling once (in a single block)
    // TODO: certora rule accrueInterest() should never decrease total collateral and total debt
    // TODO: certora rule accrueInterest() should be invisible for any other function including other silo and share tokens
    /// @inheritdoc ISilo
    function accrueInterest() external virtual returns (uint256 accruedInterest) {
        accruedInterest = _accrueInterest();
    }

    // TODO: certora rule accrueInterestForConfig() is equal to accrueInterest(). All storage should be equally updated.
    /// @inheritdoc ISilo
    function accrueInterestForConfig(address _interestRateModel, uint256 _daoFee, uint256 _deployerFee)
        external
        virtual
    {
        if (msg.sender != address(ShareTokenLib.siloConfig())) revert OnlySiloConfig();

        _accrueInterestForAsset(_interestRateModel, _daoFee, _deployerFee);
    }

    // TODO: certora rule withdrawFees() always increases dao and/or deployer (can be empty address) balances
    // TODO: certora rule withdrawFees() never increases daoAndDeployerRevenue in the same block
    // TODO: certora rule withdrawFees() always reverts in a second call in the same block
    // TODO: certora rule withdrawFees() is ghost function - it should not influence result of any other function in the system (including view functions results)
    // TODO: certora rule when all debt is paid and all collateral is withdrew, withdrawFees() always increases dao and/or deployer (can be empty address) balances and daoAndDeployerRevenue is set to 0
    /// @inheritdoc ISilo
    function withdrawFees() external virtual {
        _accrueInterest();
        Actions.withdrawFees(this);
        // TODO: emit event with paid fees
    }

    // TODO: use enum AssetType _assetType instead of uint256 _assetType - just function signature
    // TODO: should be on the top of the file
    /// @inheritdoc ISilo
    function getTotalAssetsStorage(AssetType _assetType) external view returns (uint256 totalAssetsByType) {
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
        // TODO: remove Actions.accrueInterestForAsset and call SiloLendingLib.accrueInterestForAsset
        accruedInterest = Actions.accrueInterestForAsset(_interestRateModel, _daoFee, _deployerFee);
        if (accruedInterest != 0) emit AccruedInterest(accruedInterest);
    }
}
