// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";

import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {ISilo} from "../interfaces/ISilo.sol";
import {IShareToken} from "../interfaces/IShareToken.sol";
import {IERC3156FlashBorrower} from "../interfaces/IERC3156FlashBorrower.sol";
import {IPartialLiquidation} from "../interfaces/IPartialLiquidation.sol";
import {IHookReceiver} from "../interfaces/IHookReceiver.sol";
import {IInterestRateModel} from "../interfaces/IInterestRateModel.sol";

import {SiloERC4626Lib} from "./SiloERC4626Lib.sol";
import {SiloSolvencyLib} from "./SiloSolvencyLib.sol";
import {SiloLendingLib} from "./SiloLendingLib.sol";
import {SiloStdLib} from "./SiloStdLib.sol";
import {SiloMathLib} from "./SiloMathLib.sol";
import {Hook} from "./Hook.sol";
import {Rounding} from "./Rounding.sol";
import {AssetTypes} from "./AssetTypes.sol";
import {CallBeforeQuoteLib} from "./CallBeforeQuoteLib.sol";
import {NonReentrantLib} from "./NonReentrantLib.sol";
import {ShareTokenLib} from "./ShareTokenLib.sol";
import {SiloStorageLib} from "./SiloStorageLib.sol";

library Actions {
    using SafeERC20 for IERC20;
    using Hook for uint256;
    using Hook for uint24;
    using CallBeforeQuoteLib for ISiloConfig.ConfigData;

    bytes32 internal constant _FLASHLOAN_CALLBACK = keccak256("ERC3156FlashBorrower.onFlashLoan");

    error FeeOverflow();

    function callOnBehalfOfSilo(address _target, uint256 _value, ISilo.CallType _callType, bytes calldata _input)
        internal
        returns (bool success, bytes memory result)
    {
        if (msg.sender != address(ShareTokenLib.getShareTokenStorage().hookSetup.hookReceiver)) {
            revert ISilo.OnlyHookReceiver();
        }

        // Silo will not send back any ether leftovers after the call.
        // The hook receiver should request the ether if needed in a separate call.
        if (_callType == ISilo.CallType.Delegatecall) {
            (success, result) = _target.delegatecall(_input); // solhint-disable-line avoid-low-level-calls
        } else {
            (success, result) = _target.call{value: _value}(_input); // solhint-disable-line avoid-low-level-calls
        }
    }

    function initialize(ISiloConfig _siloConfig, address _irmConfigAddress) external returns (address hookReceiver) {
        IShareToken.ShareTokenStorage storage _sharedStorage = ShareTokenLib.getShareTokenStorage();

        if (address(_sharedStorage.siloConfig) != address(0)) revert ISilo.SiloInitialized();

        ISiloConfig.ConfigData memory configData = _siloConfig.getConfig(address(this));

        _sharedStorage.siloConfig = _siloConfig;

        IInterestRateModel(configData.interestRateModel).connect(_irmConfigAddress);

        return configData.hookReceiver;
    }

    function deposit(
        uint256 _assets,
        uint256 _shares,
        address _receiver,
        ISilo.CollateralType _collateralType
    )
        external
        returns (uint256 assets, uint256 shares)
    {
        _hookCallBeforeDeposit(_collateralType, _assets, _shares, _receiver);

        ISiloConfig siloConfig = ShareTokenLib.siloConfig();

        siloConfig.turnOnReentrancyProtection();
        siloConfig.accrueInterestForSilo(address(this));

        (
            address shareToken, address asset
        ) = siloConfig.getCollateralShareTokenAndAsset(address(this), _collateralType);

        (assets, shares) = SiloERC4626Lib.deposit(
            asset,
            msg.sender,
            _assets,
            _shares,
            _receiver,
            IShareToken(shareToken),
            _collateralType
        );

        siloConfig.turnOffReentrancyProtection();

        _hookCallAfterDeposit(_collateralType, _assets, _shares, _receiver, assets, shares);
    }

    function withdraw(ISilo.WithdrawArgs calldata _args)
        external
        returns (uint256 assets, uint256 shares)
    {
        _hookCallBeforeWithdraw(_args);

        ISiloConfig siloConfig = ShareTokenLib.siloConfig();

        siloConfig.turnOnReentrancyProtection();
        siloConfig.accrueInterestForBothSilos();

        ISiloConfig.DepositConfig memory depositConfig;
        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;

        (depositConfig, collateralConfig, debtConfig) = siloConfig.getConfigsForWithdraw(address(this), _args.owner);

        (assets, shares) = SiloERC4626Lib.withdraw(
            depositConfig.token,
            _args.collateralType == ISilo.CollateralType.Collateral
                ? depositConfig.collateralShareToken
                : depositConfig.protectedShareToken,
            _args
        );

        if (depositConfig.silo == collateralConfig.silo) {
            // If deposit is collateral, then check the solvency.
            _checkSolvencyWithoutAccruingInterest(collateralConfig, debtConfig, _args.owner);
        }

        siloConfig.turnOffReentrancyProtection();

        _hookCallAfterWithdraw(_args, assets, shares);
    }

    function borrow(ISilo.BorrowArgs memory _args)
        external
        returns (uint256 assets, uint256 shares)
    {
        ISiloConfig siloConfig = ShareTokenLib.siloConfig();

        if (_args.assets == 0 && _args.shares == 0) revert ISilo.ZeroAssets();
        if (siloConfig.hasDebtInOtherSilo(address(this), _args.borrower)) revert ISilo.BorrowNotPossible();

        _hookCallBeforeBorrow(_args, Hook.BORROW);

        siloConfig.turnOnReentrancyProtection();
        siloConfig.accrueInterestForBothSilos();
        siloConfig.setOtherSiloAsCollateralSilo(_args.borrower);

        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;

        (collateralConfig, debtConfig) = siloConfig.getConfigsForBorrow({_debtSilo: address(this)});

        (assets, shares) = SiloLendingLib.borrow(
            debtConfig.debtShareToken,
            debtConfig.token,
            msg.sender,
            _args
        );

        _checkLTVWithoutAccruingInterest(collateralConfig, debtConfig, _args.borrower);

        siloConfig.turnOffReentrancyProtection();

        _hookCallAfterBorrow(_args, Hook.BORROW, assets, shares);
    }

    function borrowSameAsset(ISilo.BorrowArgs memory _args)
        external
        returns (uint256 assets, uint256 shares)
    {
        ISiloConfig siloConfig = ShareTokenLib.siloConfig();

        if (_args.assets == 0 && _args.shares == 0) revert ISilo.ZeroAssets();
        if (siloConfig.hasDebtInOtherSilo(address(this), _args.borrower)) revert ISilo.BorrowNotPossible();

        _hookCallBeforeBorrow(_args, Hook.BORROW_SAME_ASSET);

        siloConfig.turnOnReentrancyProtection();
        siloConfig.accrueInterestForSilo(address(this));
        siloConfig.setThisSiloAsCollateralSilo(_args.borrower);

        ISiloConfig.ConfigData memory collateralConfig = siloConfig.getConfig(address(this));
        ISiloConfig.ConfigData memory debtConfig = collateralConfig;

        (assets, shares) = SiloLendingLib.borrow({
            _debtShareToken: debtConfig.debtShareToken,
            _token: debtConfig.token,
            _spender: msg.sender,
            _args: _args
        });

        _checkLTVWithoutAccruingInterest(collateralConfig, debtConfig, _args.borrower);

        siloConfig.turnOffReentrancyProtection();

        _hookCallAfterBorrow(_args, Hook.BORROW_SAME_ASSET, assets, shares);
    }

    function repay(
        uint256 _assets,
        uint256 _shares,
        address _borrower,
        address _repayer
    )
        external
        returns (uint256 assets, uint256 shares)
    {
        IShareToken.ShareTokenStorage storage _shareStorage = ShareTokenLib.getShareTokenStorage();

        if (_shareStorage.hookSetup.hooksBefore.matchAction(Hook.REPAY)) {
            bytes memory data = abi.encodePacked(_assets, _shares, _borrower, _repayer);
            IHookReceiver(_shareStorage.hookSetup.hookReceiver).beforeAction(address(this), Hook.REPAY, data);
        }

        ISiloConfig siloConfig = _shareStorage.siloConfig;

        siloConfig.turnOnReentrancyProtection();
        siloConfig.accrueInterestForSilo(address(this));

        (address debtShareToken, address debtAsset) = siloConfig.getDebtShareTokenAndAsset(address(this));

        (assets, shares) = SiloLendingLib.repay(
            IShareToken(debtShareToken), debtAsset, _assets, _shares, _borrower, _repayer
        );

        siloConfig.turnOffReentrancyProtection();

        if (_shareStorage.hookSetup.hooksAfter.matchAction(Hook.REPAY)) {
            bytes memory data = abi.encodePacked(_assets, _shares, _borrower, _repayer, assets, shares);
            IHookReceiver(_shareStorage.hookSetup.hookReceiver).afterAction(address(this), Hook.REPAY, data);
        }
    }

    // solhint-disable-next-line function-max-lines
    function leverageSameAsset(ISilo.LeverageSameAssetArgs memory _args)
        external
        returns (uint256 depositedShares, uint256 borrowedShares)
    {
        ISiloConfig siloConfig = ShareTokenLib.siloConfig();

        if (_args.depositAssets == 0 || _args.borrowAssets == 0) revert ISilo.ZeroAssets();
        if (siloConfig.hasDebtInOtherSilo(address(this), _args.borrower)) revert ISilo.BorrowNotPossible();

        _hookCallBeforeLeverageSameAsset(_args);

        siloConfig.turnOnReentrancyProtection();
        siloConfig.accrueInterestForSilo(address(this));
        siloConfig.setThisSiloAsCollateralSilo(_args.borrower);

        ISiloConfig.ConfigData memory collateralConfig = siloConfig.getConfig(address(this));
        ISiloConfig.ConfigData memory debtConfig = collateralConfig;

        uint256 borrowedAssets;

        (borrowedAssets, borrowedShares) = SiloLendingLib.borrow({
            _debtShareToken: debtConfig.debtShareToken,
            _token: address(0), // we are not transferring debt
            _spender: msg.sender,
            _args: ISilo.BorrowArgs({
                assets: _args.borrowAssets,
                shares: 0,
                receiver: _args.borrower,
                borrower: _args.borrower
            })
        });

        (, depositedShares) = SiloERC4626Lib.deposit({
            _token: address(0), // we are not transferring token
            _depositor: msg.sender,
            _assets: _args.depositAssets,
            _shares: 0,
            _receiver: _args.borrower,
            _collateralShareToken: _args.collateralType == ISilo.CollateralType.Collateral
                ? IShareToken(collateralConfig.collateralShareToken)
                : IShareToken(collateralConfig.protectedShareToken),
            _collateralType: _args.collateralType
        });

        // receive collateral
        if (_args.depositAssets <= _args.borrowAssets) revert ISilo.LeverageTooHigh();
        uint256 transferDiff = _args.depositAssets - _args.borrowAssets;
        IERC20(collateralConfig.token).safeTransferFrom(msg.sender, address(this), transferDiff);

        _checkLTVWithoutAccruingInterest(collateralConfig, debtConfig, _args.borrower);

        siloConfig.turnOffReentrancyProtection();

        _hookCallAfterLeverageSameAsset(_args, borrowedAssets, depositedShares, borrowedShares);
    }

    // solhint-disable-next-line function-max-lines
    function transitionCollateral(ISilo.TransitionCollateralArgs memory _args)
        external
        returns (uint256 assets, uint256 toShares)
    {
        _hookCallBeforeTransitionCollateral(_args);

        ISiloConfig siloConfig = ShareTokenLib.siloConfig();

        siloConfig.turnOnReentrancyProtection();
        siloConfig.accrueInterestForSilo(address(this));

        (address protectedShareToken, address collateralShareToken,) = siloConfig.getShareTokens(address(this));

        uint256 shares;

        // transition collateral withdraw
        address shareTokenFrom = _args.transitionFrom == ISilo.CollateralType.Collateral
            ? collateralShareToken
            : protectedShareToken;

        (assets, shares) = SiloERC4626Lib.withdraw({
            _asset: address(0), // empty token because we don't want to transfer
            _shareToken: shareTokenFrom,
            _args: ISilo.WithdrawArgs({
                assets: 0,
                shares: _args.shares,
                owner: _args.owner,
                receiver: _args.owner,
                spender: msg.sender,
                collateralType: _args.transitionFrom
            })
        });

        // transition collateral deposit
        (ISilo.CollateralType depositType, address shareTokenTo) =
            _args.transitionFrom == ISilo.CollateralType.Collateral
                ? (ISilo.CollateralType.Protected, protectedShareToken)
                : (ISilo.CollateralType.Collateral, collateralShareToken);

        (assets, toShares) = SiloERC4626Lib.deposit({
            _token: address(0), // empty token because we don't want to transfer
            _depositor: _args.owner,
            _assets: assets,
            _shares: 0,
            _receiver: _args.owner,
            _collateralShareToken: IShareToken(shareTokenTo),
            _collateralType: depositType
        });

        siloConfig.turnOffReentrancyProtection();

        _hookCallAfterTransitionCollateral(_args, toShares, assets);
    }

    function switchCollateralToThisSilo() external {
        IShareToken.ShareTokenStorage storage _shareStorage = ShareTokenLib.getShareTokenStorage();

        ISiloConfig siloConfig = _shareStorage.siloConfig;

        if (siloConfig.borrowerCollateralSilo(msg.sender) == address(this)) revert ISilo.CollateralSiloAlreadySet();

        uint256 action = Hook.SWITCH_COLLATERAL;

        if (_shareStorage.hookSetup.hooksBefore.matchAction(action)) {
            IHookReceiver(_shareStorage.hookSetup.hookReceiver).beforeAction(
                address(this), action, abi.encodePacked(msg.sender)
            );
        }

        siloConfig.turnOnReentrancyProtection();
        siloConfig.setThisSiloAsCollateralSilo(msg.sender);

        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;

        (collateralConfig, debtConfig) = siloConfig.getConfigs(msg.sender);

        if (debtConfig.silo != address(0)) {
            siloConfig.accrueInterestForBothSilos();
            _checkSolvencyWithoutAccruingInterest(collateralConfig, debtConfig, msg.sender);
        }

        siloConfig.turnOffReentrancyProtection();

        if (_shareStorage.hookSetup.hooksBefore.matchAction(action)) {
            IHookReceiver(_shareStorage.hookSetup.hookReceiver).afterAction(
                address(this), action, abi.encodePacked(msg.sender)
            );
        }
    }

    /// @notice Executes a flash loan, sending the requested amount to the receiver and expecting it back with a fee
    /// @param _receiver The entity that will receive the flash loan and is expected to return it with a fee
    /// @param _token The token that is being borrowed in the flash loan
    /// @param _amount The amount of tokens to be borrowed
    /// @param _data Additional data to be passed to the flash loan receiver
    /// @return success A boolean indicating if the flash loan was successful
    function flashLoan(
        IERC3156FlashBorrower _receiver,
        address _token,
        uint256 _amount,
        bytes calldata _data
    )
        external
        returns (bool success)
    {
        IShareToken.ShareTokenStorage storage _shareStorage = ShareTokenLib.getShareTokenStorage();

        if (_shareStorage.hookSetup.hooksBefore.matchAction(Hook.FLASH_LOAN)) {
            bytes memory data = abi.encodePacked(_receiver, _token, _amount);
            IHookReceiver(_shareStorage.hookSetup.hookReceiver).beforeAction(address(this), Hook.FLASH_LOAN, data);
        }

        // flashFee will revert for wrong token
        uint256 fee = SiloStdLib.flashFee(_shareStorage.siloConfig, _token, _amount);

        if (fee > type(uint192).max) revert FeeOverflow();

        IERC20(_token).safeTransfer(address(_receiver), _amount);

        if (_receiver.onFlashLoan(msg.sender, _token, _amount, fee, _data) != _FLASHLOAN_CALLBACK) {
            revert ISilo.FlashloanFailed();
        }

        IERC20(_token).safeTransferFrom(address(_receiver), address(this), _amount + fee);

        // cast safe, because we checked `fee > type(uint192).max`
        SiloStorageLib.getSiloStorage().daoAndDeployerFees += uint192(fee);

        if (_shareStorage.hookSetup.hooksAfter.matchAction(Hook.FLASH_LOAN)) {
            bytes memory data = abi.encodePacked(_receiver, _token, _amount, fee);
            IHookReceiver(_shareStorage.hookSetup.hookReceiver).afterAction(address(this), Hook.FLASH_LOAN, data);
        }

        success = true;
    }

    function accrueInterestForAsset(
        address _interestRateModel,
        uint256 _daoFee,
        uint256 _deployerFee
    ) external returns (uint256 accruedInterest) {
        accruedInterest = SiloLendingLib.accrueInterestForAsset(
            _interestRateModel,
            _daoFee,
            _deployerFee
        );
    }

    /// @notice Withdraws accumulated fees and distributes them proportionally to the DAO and deployer
    /// @dev This function takes into account scenarios where either the DAO or deployer may not be set, distributing
    /// accordingly
    /// @param _silo Silo address
    function withdrawFees(ISilo _silo) external {
        ISilo.SiloStorage storage $ = SiloStorageLib.getSiloStorage();

        uint256 earnedFees = $.daoAndDeployerFees;
        if (earnedFees == 0) revert ISilo.EarnedZero();

        (
            address daoFeeReceiver,
            address deployerFeeReceiver,
            uint256 daoFee,
            uint256 deployerFee,
            address asset
        ) = SiloStdLib.getFeesAndFeeReceiversWithAsset(_silo);

        uint256 availableLiquidity;
        uint256 siloBalance = IERC20(asset).balanceOf(address(this));

        uint256 protectedAssets = $.totalAssets[AssetTypes.PROTECTED];

        // we will never underflow because `_protectedAssets` is always less/equal `siloBalance`
        unchecked { availableLiquidity = protectedAssets > siloBalance ? 0 : siloBalance - protectedAssets; }

        if (availableLiquidity == 0) revert ISilo.NoLiquidity();

        if (earnedFees > availableLiquidity) earnedFees = availableLiquidity;

        // we will never underflow because earnedFees max value is `daoAndDeployerFees`
        unchecked { $.daoAndDeployerFees -= uint192(earnedFees); }

        if (deployerFeeReceiver == address(0)) {
            // deployer was never setup or deployer NFT has been burned
            IERC20(asset).safeTransfer(daoFeeReceiver, earnedFees);
        } else {
            // split fees proportionally
            uint256 daoFees = earnedFees * daoFee;
            uint256 deployerFees;

            unchecked {
                // fees are % in decimal point so safe to uncheck
                daoFees = daoFees / (daoFee + deployerFee);
                // `daoFees` is chunk of earnedFees, so safe to uncheck
                deployerFees = earnedFees - daoFees;
            }

            IERC20(asset).safeTransfer(daoFeeReceiver, daoFees);
            IERC20(asset).safeTransfer(deployerFeeReceiver, deployerFees);
        }
    }

    function updateHooks() external returns (uint24 hooksBefore, uint24 hooksAfter) {
        ISiloConfig siloConfig = ShareTokenLib.siloConfig();

        NonReentrantLib.nonReentrant(siloConfig);

        ISiloConfig.ConfigData memory cfg = siloConfig.getConfig(address(this));

        if (cfg.hookReceiver == address(0)) return (0, 0);

        (hooksBefore, hooksAfter) = IHookReceiver(cfg.hookReceiver).hookReceiverConfig(address(this));

        IShareToken(cfg.collateralShareToken).synchronizeHooks(hooksBefore, hooksAfter);
        IShareToken(cfg.protectedShareToken).synchronizeHooks(hooksBefore, hooksAfter);
        IShareToken(cfg.debtShareToken).synchronizeHooks(hooksBefore, hooksAfter);
    }

    // this method expect interest to be already accrued
    function _checkSolvencyWithoutAccruingInterest(
        ISiloConfig.ConfigData memory collateralConfig,
        ISiloConfig.ConfigData memory debtConfig,
        address _user
    ) private {
        if (debtConfig.silo != collateralConfig.silo) {
            collateralConfig.callSolvencyOracleBeforeQuote();
            debtConfig.callSolvencyOracleBeforeQuote();
        }

        bool userIsSolvent = SiloSolvencyLib.isSolvent(
            collateralConfig, debtConfig, _user, ISilo.AccrueInterestInMemory.No
        );

        if (!userIsSolvent) revert ISilo.NotSolvent();
    }

    // this method expect interest to be already accrued
    function _checkLTVWithoutAccruingInterest(
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address _borrower
    ) private {
        if (_collateralConfig.silo != _debtConfig.silo) {
            _collateralConfig.callMaxLtvOracleBeforeQuote();
            _debtConfig.callMaxLtvOracleBeforeQuote();
        }

        bool borrowerIsBelowMaxLtv = SiloSolvencyLib.isBelowMaxLtv(
            _collateralConfig, _debtConfig, _borrower, ISilo.AccrueInterestInMemory.No
        );

        if (!borrowerIsBelowMaxLtv) revert ISilo.AboveMaxLtv();
    }

    function _hookCallBeforeWithdraw(
        ISilo.WithdrawArgs calldata _args
    ) private {
        IShareToken.ShareTokenStorage storage _shareStorage = ShareTokenLib.getShareTokenStorage();

        uint256 action = Hook.withdrawAction(_args.collateralType);

        if (!_shareStorage.hookSetup.hooksBefore.matchAction(action)) return;

        bytes memory data =
            abi.encodePacked(_args.assets, _args.shares, _args.receiver, _args.owner, _args.spender);

        IHookReceiver(_shareStorage.hookSetup.hookReceiver).beforeAction(address(this), action, data);
    }

    function _hookCallAfterWithdraw(
        ISilo.WithdrawArgs calldata _args,
        uint256 assets,
        uint256 shares
    ) private {
        IShareToken.ShareTokenStorage storage _shareStorage = ShareTokenLib.getShareTokenStorage();

        uint256 action = Hook.withdrawAction(_args.collateralType);

        if (!_shareStorage.hookSetup.hooksAfter.matchAction(action)) return;

        bytes memory data =
            abi.encodePacked(_args.assets, _args.shares, _args.receiver, _args.owner, _args.spender, assets, shares);

        IHookReceiver(_shareStorage.hookSetup.hookReceiver).afterAction(address(this), action, data);
    }

    function _hookCallBeforeBorrow(
        ISilo.BorrowArgs memory _args,
        uint256 action
    ) private {
        IShareToken.ShareTokenStorage storage _shareStorage = ShareTokenLib.getShareTokenStorage();

        if (!_shareStorage.hookSetup.hooksBefore.matchAction(action)) return;

        bytes memory data = abi.encodePacked(_args.assets, _args.shares, _args.receiver, _args.borrower);

        IHookReceiver(_shareStorage.hookSetup.hookReceiver).beforeAction(address(this), action, data);
    }

    function _hookCallAfterBorrow(
        ISilo.BorrowArgs memory _args,
        uint256 action,
        uint256 assets,
        uint256 shares
    ) private {
        IShareToken.ShareTokenStorage storage _shareStorage = ShareTokenLib.getShareTokenStorage();

        if (!_shareStorage.hookSetup.hooksAfter.matchAction(action)) return;

        bytes memory data = abi.encodePacked(
            _args.assets,
            _args.shares,
            _args.receiver,
            _args.borrower,
            assets,
            shares
        );

        IHookReceiver(_shareStorage.hookSetup.hookReceiver).afterAction(address(this), action, data);
    }

    function _hookCallBeforeTransitionCollateral(ISilo.TransitionCollateralArgs memory _args) private {
        IShareToken.ShareTokenStorage storage _shareStorage = ShareTokenLib.getShareTokenStorage();
        
        uint256 action = Hook.transitionCollateralAction(_args.transitionFrom);

        if (!_shareStorage.hookSetup.hooksBefore.matchAction(action)) return;

        bytes memory data = abi.encodePacked(_args.shares, _args.owner);

        IHookReceiver(_shareStorage.hookSetup.hookReceiver).beforeAction(address(this), action, data);
    }

    function _hookCallAfterTransitionCollateral(
        ISilo.TransitionCollateralArgs memory _args,
        uint256 _shares,
        uint256 _assets
    ) private {
        IShareToken.ShareTokenStorage storage _shareStorage = ShareTokenLib.getShareTokenStorage();
        uint256 action = Hook.transitionCollateralAction(_args.transitionFrom);

        if (!_shareStorage.hookSetup.hooksAfter.matchAction(action)) return;

        bytes memory data = abi.encodePacked(_shares, _args.owner, _assets);

        IHookReceiver(_shareStorage.hookSetup.hookReceiver).afterAction(address(this), action, data);
    }

    function _hookCallBeforeDeposit(
        ISilo.CollateralType _collateralType,
        uint256 _assets,
        uint256 _shares,
        address _receiver
    ) private {
        IShareToken.ShareTokenStorage storage _shareStorage = ShareTokenLib.getShareTokenStorage();
        uint256 action = Hook.depositAction(_collateralType);

        if (!_shareStorage.hookSetup.hooksBefore.matchAction(action)) return;

        bytes memory data = abi.encodePacked(_assets, _shares, _receiver);

        IHookReceiver(_shareStorage.hookSetup.hookReceiver).beforeAction(address(this), action, data);
    }

    function _hookCallAfterDeposit(
        ISilo.CollateralType _collateralType,
        uint256 _assets,
        uint256 _shares,
        address _receiver,
        uint256 _exactAssets,
        uint256 _exactShare
    ) private {
        IShareToken.ShareTokenStorage storage _shareStorage = ShareTokenLib.getShareTokenStorage();
        uint256 action = Hook.depositAction(_collateralType);

        if (!_shareStorage.hookSetup.hooksAfter.matchAction(action)) return;

        bytes memory data = abi.encodePacked(_assets, _shares, _receiver, _exactAssets, _exactShare);

        IHookReceiver(_shareStorage.hookSetup.hookReceiver).afterAction(address(this), action, data);
    }

    function _hookCallBeforeLeverageSameAsset(ISilo.LeverageSameAssetArgs memory _args) private {
        IShareToken.ShareTokenStorage storage _shareStorage = ShareTokenLib.getShareTokenStorage();

        if (!_shareStorage.hookSetup.hooksBefore.matchAction(Hook.LEVERAGE_SAME_ASSET)) return;

        bytes memory data = abi.encodePacked(
            _args.depositAssets, _args.borrowAssets, _args.borrower, _args.collateralType
        );

        IHookReceiver(_shareStorage.hookSetup.hookReceiver).beforeAction(address(this), Hook.LEVERAGE_SAME_ASSET, data);
    }

    function _hookCallAfterLeverageSameAsset(
        ISilo.LeverageSameAssetArgs memory _args,
        uint256 _borrowedAssets,
        uint256 _depositedShares,
        uint256 _borrowedShares
    ) private {
        IShareToken.ShareTokenStorage storage _shareStorage = ShareTokenLib.getShareTokenStorage();

        if (!_shareStorage.hookSetup.hooksAfter.matchAction(Hook.LEVERAGE_SAME_ASSET)) return;

        bytes memory data = abi.encodePacked(
            _args.depositAssets,
            _borrowedAssets,
            _args.borrower,
            _args.collateralType,
            _depositedShares,
            _borrowedShares
        );

        IHookReceiver(_shareStorage.hookSetup.hookReceiver).afterAction(address(this), Hook.LEVERAGE_SAME_ASSET, data);
    }
}
