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

import {SiloERC4626Lib} from "./SiloERC4626Lib.sol";
import {SiloSolvencyLib} from "./SiloSolvencyLib.sol";
import {SiloLendingLib} from "./SiloLendingLib.sol";
import {SiloStdLib} from "./SiloStdLib.sol";
import {SiloMathLib} from "./SiloMathLib.sol";
import {Hook} from "./Hook.sol";
import {AssetTypes} from "./AssetTypes.sol";
import {CallBeforeQuoteLib} from "./CallBeforeQuoteLib.sol";

library Actions {
    using SafeERC20 for IERC20;
    using Hook for uint256;
    using Hook for uint24;
    using CallBeforeQuoteLib for ISiloConfig.ConfigData;

    bytes32 internal constant _FLASHLOAN_CALLBACK = keccak256("ERC3156FlashBorrower.onFlashLoan");

    error FeeOverflow();

    function deposit(
        ISilo.SharedStorage storage _shareStorage,
        uint256 _assets,
        uint256 _shares,
        address _receiver,
        ISilo.CollateralType _collateralType,
        ISilo.Assets storage _totalCollateral
    )
        external
        returns (uint256 assets, uint256 shares)
    {
        _hookCallBeforeDeposit(_shareStorage, _collateralType, _assets, _shares, _receiver);

        ISiloConfig siloConfig = _shareStorage.siloConfig;

        siloConfig.turnOnReentrancyProtection();
        siloConfig.accrueInterestForSilo(address(this));

        (
            address shareToken, address asset
        ) = siloConfig.getCollateralShareTokenAndSiloToken(address(this), _collateralType);

        (assets, shares) = SiloERC4626Lib.deposit(
            asset,
            msg.sender,
            _assets,
            _shares,
            _receiver,
            IShareToken(shareToken),
            _totalCollateral
        );

        siloConfig.turnOffReentrancyProtection();

        _hookCallAfterDeposit(_shareStorage, _collateralType, _assets, _shares, _receiver, assets, shares);
    }

    function withdraw(
        ISilo.SharedStorage storage _shareStorage,
        ISilo.WithdrawArgs calldata _args,
        ISilo.Assets storage _totalAssets,
        ISilo.Assets storage _totalDebtAssets
    )
        external
        returns (uint256 assets, uint256 shares)
    {
        ISiloConfig siloConfig = _shareStorage.siloConfig;

        _hookCallBeforeWithdraw(_shareStorage, _args);

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
            _args,
            _args.collateralType == ISilo.CollateralType.Collateral
                ? SiloMathLib.liquidity(_totalAssets.assets, _totalDebtAssets.assets)
                : _totalAssets.assets,
            _totalAssets
        );

        if (depositConfig.silo == collateralConfig.silo) {
            // If deposit is collateral, then check the solvency.
            _checkSolvency(collateralConfig, debtConfig, _args.owner);
        }

        siloConfig.turnOffReentrancyProtection();

        _hookCallAfterWithdraw(_shareStorage, _args, assets, shares);
    }

    function borrow(
        ISilo.SharedStorage storage _shareStorage,
        ISilo.BorrowArgs memory _args,
        ISilo.Assets storage _totalCollateral,
        ISilo.Assets storage _totalDebt
    )
        external
        returns (uint256 assets, uint256 shares)
    {
        ISiloConfig siloConfig = _shareStorage.siloConfig;
        uint256 borrowAction = Hook.borrowAction(_args.sameAsset);

        if (_args.assets == 0 && _args.shares == 0) revert ISilo.ZeroAssets();
        if (siloConfig.hasDebtInOtherSilo(address(this), _args.borrower)) revert ISilo.BorrowNotPossible();

        _hookCallBeforeBorrow(_shareStorage, _args, borrowAction);

        siloConfig.turnOnReentrancyProtection();
        siloConfig.accrueInterestForBothSilos();
        siloConfig.setCollateralSilo(_args.borrower, _args.sameAsset);

        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;

        (collateralConfig, debtConfig) = siloConfig.getConfigsForBorrow(address(this), _args.sameAsset);

        (assets, shares) = SiloLendingLib.borrow(
            debtConfig.debtShareToken,
            debtConfig.token,
            msg.sender,
            _args,
            _totalCollateral.assets,
            _totalDebt
        );

        _checkLTV(collateralConfig, debtConfig, _args.borrower);

        siloConfig.turnOffReentrancyProtection();

        _hookCallAfterBorrow(_shareStorage, _args, borrowAction, assets, shares);
    }

    function repay(
        ISilo.SharedStorage storage _shareStorage,
        uint256 _assets,
        uint256 _shares,
        address _borrower,
        address _repayer,
        ISilo.Assets storage _totalDebt
    )
        external
        returns (uint256 assets, uint256 shares)
    {
        if (_shareStorage.hooksBefore.matchAction(Hook.REPAY)) {
            bytes memory data = abi.encodePacked(_assets, _shares, _borrower, _repayer);
            _shareStorage.hookReceiver.beforeAction(address(this), Hook.REPAY, data);
        }

        ISiloConfig siloConfig = _shareStorage.siloConfig;

        siloConfig.turnOnReentrancyProtection();
        siloConfig.accrueInterestForSilo(address(this));

        (address debtShareToken, address debtAsset) = siloConfig.getDebtShareTokenAndAsset(address(this));

        (assets, shares) = SiloLendingLib.repay(
            IShareToken(debtShareToken), debtAsset, _assets, _shares, _borrower, _repayer, _totalDebt
        );

        siloConfig.turnOffReentrancyProtection();

        if (_shareStorage.hooksAfter.matchAction(Hook.REPAY)) {
            bytes memory data = abi.encodePacked(_assets, _shares, _borrower, _repayer, assets, shares);
            _shareStorage.hookReceiver.afterAction(address(this), Hook.REPAY, data);
        }
    }

    // solhint-disable-next-line function-max-lines
    function leverageSameAsset(
        ISilo.SharedStorage storage _shareStorage,
        ISilo.Assets storage _totalCollateral,
        ISilo.Assets storage _totalDebt,
        ISilo.Assets storage _totalAssetsForDeposit,
        ISilo.LeverageSameAssetArgs memory _args
    )
        external
        returns (uint256 depositedShares, uint256 borrowedShares)
    {
        ISiloConfig siloConfig = _shareStorage.siloConfig;

        if (_args.depositAssets == 0 || _args.borrowAssets == 0) revert ISilo.ZeroAssets();
        if (siloConfig.hasDebtInOtherSilo(address(this), _args.borrower)) revert ISilo.BorrowNotPossible();

        _hookCallBeforeLeverageSameAsset(_shareStorage, _args);

        siloConfig.turnOnReentrancyProtection();
        siloConfig.accrueInterestForSilo(address(this));
        siloConfig.setCollateralSilo({_borrower: _args.borrower, _sameAsset: true});

        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;

        (collateralConfig, debtConfig) = siloConfig.getConfigsForBorrow({_silo: address(this), _sameAsset: true});

        uint256 borrowedAssets;

        (borrowedAssets, borrowedShares) = SiloLendingLib.borrow({
            _debtShareToken: debtConfig.debtShareToken,
            _token: address(0), // we are not transferring debt
            _spender: msg.sender,
            _args: ISilo.BorrowArgs({
                assets: _args.borrowAssets,
                shares: 0,
                receiver: _args.borrower,
                borrower: _args.borrower,
                sameAsset: true
            }),
            _totalCollateralAssets: _totalCollateral.assets,
            _totalDebt: _totalDebt
        });

        _receiveCollateralOnLeverageSameAsset(collateralConfig, _args.depositAssets, borrowedAssets);

        (, depositedShares) = SiloERC4626Lib.deposit({
            _token: address(0), // we are not transferring token
            _depositor: msg.sender,
            _assets: _args.depositAssets,
            _shares: 0,
            _receiver: _args.borrower,
            _collateralShareToken: _args.collateralType == ISilo.CollateralType.Collateral
                ? IShareToken(collateralConfig.collateralShareToken)
                : IShareToken(collateralConfig.protectedShareToken),
            _totalCollateral: _totalAssetsForDeposit
        });

        _checkLTV(collateralConfig, debtConfig, _args.borrower);

        _shareStorage.siloConfig.turnOffReentrancyProtection();

        _hookCallAfterLeverageSameAsset(_shareStorage, _args, borrowedAssets, depositedShares, borrowedShares);
    }

    function transitionCollateral(
        ISilo.SharedStorage storage _shareStorage,
        mapping(uint256 assetType => ISilo.Assets) storage _total,
        ISilo.TransitionCollateralArgs memory _args
    )
        external
        returns (uint256 assets, uint256 toShares)
    {
        _hookCallBeforeTransitionCollateral(_shareStorage, _args);

        ISiloConfig siloConfig = _shareStorage.siloConfig;

        siloConfig.turnOnReentrancyProtection();
        siloConfig.accrueInterestForSilo(address(this));

        (address protectedShareToken, address collateralShareToken,) = siloConfig.getShareTokens(address(this));

        uint256 shares;

        (assets, shares) = _transitionCollateralWithdraw(_total, _args, protectedShareToken, collateralShareToken);

        (assets, toShares) = _transitionCollateralDeposit(
            _total,
            _args,
            assets,
            protectedShareToken,
            collateralShareToken
        );

        _shareStorage.siloConfig.turnOffReentrancyProtection();

        _hookCallAfterTransitionCollateral(_shareStorage, _args, shares, assets);
    }

    function switchCollateralTo(ISilo.SharedStorage storage _shareStorage) external {
        uint256 action = Hook.SWITCH_COLLATERAL;

        if (_shareStorage.hooksBefore.matchAction(action)) {
            _shareStorage.hookReceiver.beforeAction(address(this), action, abi.encodePacked(msg.sender));
        }

        ISiloConfig siloConfig = _shareStorage.siloConfig;

        siloConfig.turnOnReentrancyProtection();
        siloConfig.accrueInterestForBothSilos();
        siloConfig.switchCollateralSilo(msg.sender);

        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;

        (collateralConfig, debtConfig) = siloConfig.getCollateralAndDebtConfigs(msg.sender);

        _checkSolvency(collateralConfig, debtConfig, msg.sender);

        siloConfig.turnOffReentrancyProtection();

        if (_shareStorage.hooksBefore.matchAction(action)) {
            _shareStorage.hookReceiver.afterAction(address(this), action, abi.encodePacked(msg.sender));
        }
    }

    /// @notice Executes a flash loan, sending the requested amount to the receiver and expecting it back with a fee
    /// @param _receiver The entity that will receive the flash loan and is expected to return it with a fee
    /// @param _token The token that is being borrowed in the flash loan
    /// @param _amount The amount of tokens to be borrowed
    /// @param _siloData Storage containing data related to fees
    /// @param _data Additional data to be passed to the flash loan receiver
    /// @return success A boolean indicating if the flash loan was successful
    function flashLoan(
        ISilo.SharedStorage storage _shareStorage,
        IERC3156FlashBorrower _receiver,
        address _token,
        uint256 _amount,
        ISilo.SiloData storage _siloData,
        bytes calldata _data
    )
        external
        returns (bool success)
    {
        if (_shareStorage.hooksBefore.matchAction(Hook.FLASH_LOAN)) {
            bytes memory data = abi.encodePacked(_receiver, _token, _amount);
            _shareStorage.hookReceiver.beforeAction(address(this), Hook.FLASH_LOAN, data);
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
        _siloData.daoAndDeployerFees += uint192(fee);

        if (_shareStorage.hooksAfter.matchAction(Hook.FLASH_LOAN)) {
            bytes memory data = abi.encodePacked(_receiver, _token, _amount, fee);
            _shareStorage.hookReceiver.afterAction(address(this), Hook.FLASH_LOAN, data);
        }

        success = true;
    }

    /// @notice Withdraws accumulated fees and distributes them proportionally to the DAO and deployer
    /// @dev This function takes into account scenarios where either the DAO or deployer may not be set, distributing
    /// accordingly
    /// @param _silo Silo address
    /// @param _siloData Storage reference containing silo-related data, including accumulated fees
    /// @param _protectedAssets Protected assets in the silo. We can not withdraw it.
    function withdrawFees(ISilo _silo, ISilo.SiloData storage _siloData, uint256 _protectedAssets) external {
        uint256 earnedFees = _siloData.daoAndDeployerFees;
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

        // we will never underflow because `_protectedAssets` is always less/equal `siloBalance`
        unchecked { availableLiquidity = _protectedAssets > siloBalance ? 0 : siloBalance - _protectedAssets; }

        if (availableLiquidity == 0) revert ISilo.NoLiquidity();


        if (earnedFees > availableLiquidity) earnedFees = availableLiquidity;

        // we will never underflow because earnedFees max value is `_siloData.daoAndDeployerFees`
        unchecked { _siloData.daoAndDeployerFees -= uint192(earnedFees); }

        if (daoFeeReceiver == address(0) && deployerFeeReceiver == address(0)) {
            // just in case, should never happen...
            revert ISilo.NothingToPay();
        } else if (deployerFeeReceiver == address(0)) {
            // deployer was never setup or deployer NFT has been burned
            IERC20(asset).safeTransfer(daoFeeReceiver, earnedFees);
        } else if (daoFeeReceiver == address(0)) {
            // should never happen... but we assume DAO does not want to make money so all is going to deployer
            IERC20(asset).safeTransfer(deployerFeeReceiver, earnedFees);
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

    function updateHooks(ISilo.SharedStorage storage _sharedStorage)
        external
        returns (uint24 hooksBefore, uint24 hooksAfter)
    {
        ISilo.SharedStorage memory shareStorage = _sharedStorage;

        ISiloConfig.ConfigData memory cfg = shareStorage.siloConfig.getConfig(address(this));

        if (cfg.hookReceiver == address(0)) return (hooksBefore, hooksAfter);

        (hooksBefore, hooksAfter) = IHookReceiver(cfg.hookReceiver).hookReceiverConfig(address(this));

        _sharedStorage.hooksBefore = hooksBefore;
        _sharedStorage.hooksAfter = hooksAfter;

        IShareToken(cfg.collateralShareToken).synchronizeHooks(hooksBefore, hooksAfter);
        IShareToken(cfg.protectedShareToken).synchronizeHooks(hooksBefore, hooksAfter);
        IShareToken(cfg.debtShareToken).synchronizeHooks(hooksBefore, hooksAfter);
    }

    function _receiveCollateralOnLeverageSameAsset(
        ISiloConfig.ConfigData memory collateralConfig,
        uint256 _depositAssets,
        uint256 _borrowedAssets
    ) private {
        uint256 requiredCollateral = _borrowedAssets * SiloLendingLib._PRECISION_DECIMALS;
        uint256 transferDiff;

        unchecked { requiredCollateral = requiredCollateral / collateralConfig.maxLtv; }

        if (_depositAssets < requiredCollateral) revert ISilo.LeverageTooHigh();

        unchecked {
            // safe because `requiredCollateral` > `_depositAssets`
            // and `_borrowedAssets` is chunk of `requiredCollateral`
            transferDiff = _depositAssets - _borrowedAssets;
        }

        IERC20(collateralConfig.token).safeTransferFrom(msg.sender, address(this), transferDiff);
    }

    function _checkSolvency(
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

    function _checkLTV(
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

    function _transitionCollateralWithdraw(
        mapping(uint256 assetType => ISilo.Assets) storage _total,
        ISilo.TransitionCollateralArgs memory _args,
        address _protectedShareToken,
        address _collateralShareToken
    ) private returns (uint256 assets, uint256 toShares) {
        uint256 liquidity = _args.withdrawType == ISilo.CollateralType.Collateral
            ? SiloMathLib.liquidity(_total[AssetTypes.COLLATERAL].assets, _total[AssetTypes.DEBT].assets)
            : _total[AssetTypes.PROTECTED].assets;

        address shareTokenFrom = _args.withdrawType == ISilo.CollateralType.Collateral
            ? _collateralShareToken
            : _protectedShareToken;

        (assets, toShares) = SiloERC4626Lib.withdraw({
            _asset: address(0), // empty token because we don't want to transfer
            _shareToken: shareTokenFrom,
            _args: ISilo.WithdrawArgs({
                assets: 0,
                shares: _args.shares,
                owner: _args.owner,
                receiver: _args.owner,
                spender: msg.sender,
                collateralType: _args.withdrawType
            }),
            _liquidity: liquidity,
            _totalCollateral: _total[uint256(_args.withdrawType)]
        });
    }

    function _transitionCollateralDeposit(
        mapping(uint256 assetType => ISilo.Assets) storage _total,
        ISilo.TransitionCollateralArgs memory _args,
        uint256 _assets,
        address _protectedShareToken,
        address _collateralShareToken
    ) private returns (uint256 assets, uint256 toShares) {
        (ISilo.AssetType depositType, address shareTokenTo) = _args.withdrawType == ISilo.CollateralType.Collateral
            ? (ISilo.AssetType.Protected, _protectedShareToken)
            : (ISilo.AssetType.Collateral, _collateralShareToken);

        (assets, toShares) = SiloERC4626Lib.deposit({
            _token: address(0), // empty token because we don't want to transfer
            _depositor: _args.owner,
            _assets: _assets,
            _shares: 0,
            _receiver: _args.owner,
            _collateralShareToken: IShareToken(shareTokenTo),
            _totalCollateral: _total[uint256(depositType)]
        
        });
    }

    function _hookCallBeforeWithdraw(
        ISilo.SharedStorage storage _shareStorage,
        ISilo.WithdrawArgs calldata _args
    ) private {
        uint256 action = Hook.withdrawAction(_args.collateralType);

        if (!_shareStorage.hooksBefore.matchAction(action)) return;

        bytes memory data =
            abi.encodePacked(_args.assets, _args.shares, _args.receiver, _args.owner, _args.spender);

        _shareStorage.hookReceiver.beforeAction(address(this), action, data);
    }

    function _hookCallAfterWithdraw(
        ISilo.SharedStorage storage _shareStorage,
        ISilo.WithdrawArgs calldata _args,
        uint256 assets,
        uint256 shares
    ) private {
        uint256 action = Hook.withdrawAction(_args.collateralType);

        if (!_shareStorage.hooksAfter.matchAction(action)) return;

        bytes memory data =
            abi.encodePacked(_args.assets, _args.shares, _args.receiver, _args.owner, _args.spender, assets, shares);

        _shareStorage.hookReceiver.afterAction(address(this), action, data);
    }

    function _hookCallBeforeBorrow(
        ISilo.SharedStorage storage _shareStorage,
        ISilo.BorrowArgs memory _args,
        uint256 action
    ) private {
        if (!_shareStorage.hooksBefore.matchAction(action)) return;

        bytes memory data = abi.encodePacked(_args.assets, _args.shares, _args.receiver, _args.borrower);

        _shareStorage.hookReceiver.beforeAction(address(this), action, data);
    }

    function _hookCallAfterBorrow(
        ISilo.SharedStorage storage _shareStorage,
        ISilo.BorrowArgs memory _args,
        uint256 action,
        uint256 assets,
        uint256 shares
    ) private {
        if (!_shareStorage.hooksAfter.matchAction(action)) return;

        bytes memory data = abi.encodePacked(
            _args.assets,
            _args.shares,
            _args.receiver,
            _args.borrower,
            assets,
            shares
        );

        _shareStorage.hookReceiver.afterAction(address(this), action, data);
    }

    function _hookCallBeforeTransitionCollateral(
        ISilo.SharedStorage storage _shareStorage,
        ISilo.TransitionCollateralArgs memory _args
    ) private {
        uint256 action = Hook.transitionCollateralAction(_args.withdrawType);

        if (!_shareStorage.hooksBefore.matchAction(action)) return;

        bytes memory data = abi.encodePacked(_args.shares, _args.owner);

        _shareStorage.hookReceiver.beforeAction(address(this), action, data);
    }

    function _hookCallAfterTransitionCollateral(
        ISilo.SharedStorage storage _shareStorage,
        ISilo.TransitionCollateralArgs memory _args,
        uint256 _shares,
        uint256 _assets
    ) private {
        uint256 action = Hook.transitionCollateralAction(_args.withdrawType);

        if (!_shareStorage.hooksAfter.matchAction(action)) return;

        bytes memory data = abi.encodePacked(_shares, _args.owner, _assets);

        _shareStorage.hookReceiver.afterAction(address(this), action, data);
    }

    function _hookCallBeforeDeposit(
        ISilo.SharedStorage storage _shareStorage,
        ISilo.CollateralType _collateralType,
        uint256 _assets,
        uint256 _shares,
        address _receiver
    ) private {
        uint256 action = Hook.depositAction(_collateralType);

        if (!_shareStorage.hooksBefore.matchAction(action)) return;

        bytes memory data = abi.encodePacked(_assets, _shares, _receiver);

        _shareStorage.hookReceiver.beforeAction(address(this), action, data);
    }

    function _hookCallAfterDeposit(
        ISilo.SharedStorage storage _shareStorage,
        ISilo.CollateralType _collateralType,
        uint256 _assets,
        uint256 _shares,
        address _receiver,
        uint256 _exactAssets,
        uint256 _exactShare
    ) private {
        uint256 action = Hook.depositAction(_collateralType);

        if (!_shareStorage.hooksAfter.matchAction(action)) return;

        bytes memory data = abi.encodePacked(_assets, _shares, _receiver, _exactAssets, _exactShare);

        _shareStorage.hookReceiver.afterAction(address(this), action, data);
    }

    function _hookCallBeforeLeverageSameAsset(
        ISilo.SharedStorage storage _shareStorage,
        ISilo.LeverageSameAssetArgs memory _args
    ) private {
        if (!_shareStorage.hooksBefore.matchAction(Hook.LEVERAGE_SAME_ASSET)) return;

        bytes memory data = abi.encodePacked(
            _args.depositAssets, _args.borrowAssets, _args.borrower, _args.collateralType
        );

        _shareStorage.hookReceiver.beforeAction(address(this), Hook.LEVERAGE_SAME_ASSET, data);
    }

    function _hookCallAfterLeverageSameAsset(
        ISilo.SharedStorage storage _shareStorage,
        ISilo.LeverageSameAssetArgs memory _args,
        uint256 _borrowedAssets,
        uint256 _depositedShares,
        uint256 _borrowedShares
    ) private {
        if (!_shareStorage.hooksAfter.matchAction(Hook.LEVERAGE_SAME_ASSET)) return;

        bytes memory data = abi.encodePacked(
            _args.depositAssets,
            _borrowedAssets,
            _args.borrower,
            _args.collateralType,
            _depositedShares,
            _borrowedShares
        );

        _shareStorage.hookReceiver.afterAction(address(this), Hook.LEVERAGE_SAME_ASSET, data);
    }
}
