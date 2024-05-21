// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";

import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {ISilo} from "../interfaces/ISilo.sol";
import {IShareToken} from "../interfaces/IShareToken.sol";
import {ILeverageBorrower} from "../interfaces/ILeverageBorrower.sol";
import {IERC3156FlashBorrower} from "../interfaces/IERC3156FlashBorrower.sol";
import {IPartialLiquidation} from "../interfaces/IPartialLiquidation.sol";
import {IHookReceiver} from "../interfaces/IHookReceiver.sol";

import {SiloERC4626Lib} from "./SiloERC4626Lib.sol";
import {SiloSolvencyLib} from "./SiloSolvencyLib.sol";
import {SiloLendingLib} from "./SiloLendingLib.sol";
import {SiloStdLib} from "./SiloStdLib.sol";
import {SiloMathLib} from "./SiloMathLib.sol";
import {CrossEntrancy} from "./CrossEntrancy.sol";
import {Hook} from "./Hook.sol";
import {AssetTypes} from "./AssetTypes.sol";
import {CallBeforeQuoteLib} from "./CallBeforeQuoteLib.sol";

library Actions {
    using SafeERC20 for IERC20;
    using Hook for uint256;
    using Hook for uint24;
    using CallBeforeQuoteLib for ISiloConfig.ConfigData;

    bytes32 internal constant _LEVERAGE_CALLBACK = keccak256("ILeverageBorrower.onLeverage");
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
        _hookCallBefore(_shareStorage, Hook.DEPOSIT, abi.encodePacked(_assets, _shares, _receiver, _collateralType));

        (
            address shareToken,
            address asset,
            address hookReceiver,
        ) = _shareStorage.siloConfig.accrueInterestAndGetConfigOptimised(Hook.DEPOSIT, _collateralType);

        (assets, shares) = SiloERC4626Lib.deposit(
            asset,
            msg.sender,
            _assets,
            _shares,
            _receiver,
            IShareToken(shareToken),
            _totalCollateral
        );

        _shareStorage.siloConfig.crossNonReentrantAfter();

        if (hookReceiver != address(0)) {
            _hookCallAfter(
                _shareStorage,
                hookReceiver,
                Hook.DEPOSIT,
                abi.encodePacked(_assets, _shares, _receiver, _collateralType, assets, shares)
            );
        }
    }

    // solhint-disable-next-line function-max-lines, code-complexity
    function withdraw(
        ISilo.SharedStorage storage _shareStorage,
        ISilo.WithdrawArgs calldata _args,
        ISilo.Assets storage _totalAssets,
        ISilo.Assets storage _totalDebtAssets
    )
        external
        returns (uint256 assets, uint256 shares)
    {
        _hookCallBefore(
            _shareStorage,
            Hook.WITHDRAW |
                (_args.collateralType == ISilo.CollateralType.Collateral
                    ? Hook.COLLATERAL_TOKEN
                    : Hook.PROTECTED_TOKEN
                ),
            abi.encodePacked(
                _args.assets, _args.shares, _args.receiver, _args.owner, _args.spender, _args.collateralType
            )
        );

        (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig,
            ISiloConfig.DebtInfo memory debtInfo
        ) = _shareStorage.siloConfig.accrueInterestAndGetConfigs(address(this), _args.owner, Hook.WITHDRAW);

        if (collateralConfig.silo != debtConfig.silo) ISilo(debtConfig.silo).accrueInterest();

        // this `if` helped with Stack too deep
        if (_args.collateralType == ISilo.CollateralType.Collateral) {
            (assets, shares) = SiloERC4626Lib.withdraw(
                collateralConfig.token,
                collateralConfig.collateralShareToken,
                _args,
                SiloMathLib.liquidity(_totalAssets.assets, _totalDebtAssets.assets),
                _totalAssets
            );
        } else {
            (assets, shares) = SiloERC4626Lib.withdraw(
                collateralConfig.token,
                collateralConfig.protectedShareToken,
                _args,
                _totalAssets.assets,
                _totalAssets
            );
        }

        if (SiloSolvencyLib.depositWithoutDebt(debtInfo)) {
            _shareStorage.siloConfig.crossNonReentrantAfter();

            if (collateralConfig.hookReceiver != address(0)) {
                _hookCallAfter(
                    _shareStorage,
                    collateralConfig.hookReceiver,
                    Hook.WITHDRAW |
                        (_args.collateralType == ISilo.CollateralType.Collateral
                            ? Hook.COLLATERAL_TOKEN
                            : Hook.PROTECTED_TOKEN),
                    abi.encodePacked(
                        _args.assets,
                        _args.shares,
                        _args.receiver,
                        _args.owner,
                        _args.spender,
                        assets,
                        shares
                    )
                );
            }

            return (assets, shares);
        }

        if (!debtInfo.sameAsset) {
            collateralConfig.callSolvencyOracleBeforeQuote();
            debtConfig.callSolvencyOracleBeforeQuote();
        }

        // `_args.owner` must be solvent
        if (!SiloSolvencyLib.isSolvent(
            collateralConfig, debtConfig, debtInfo, _args.owner, ISilo.AccrueInterestInMemory.No
        )) revert ISilo.NotSolvent();

        _shareStorage.siloConfig.crossNonReentrantAfter();

        if (collateralConfig.hookReceiver != address(0)) {
            _hookCallAfter(
                _shareStorage,
                collateralConfig.hookReceiver,
                Hook.WITHDRAW |
                    (_args.collateralType == ISilo.CollateralType.Collateral
                        ? Hook.COLLATERAL_TOKEN
                        : Hook.PROTECTED_TOKEN
                    ),
                abi.encodePacked(
                    _args.assets,
                    _args.shares,
                    _args.receiver,
                    _args.owner,
                    _args.spender,
                    assets,
                    shares
                )
            );
        }
    }

    // solhint-disable-next-line function-max-lines, code-complexity
    function borrow(
        ISilo.SharedStorage storage _shareStorage,
        ISilo.BorrowArgs memory _args,
        ISilo.Assets storage _totalCollateral,
        ISilo.Assets storage _totalDebt,
        bytes memory _data
    )
        external
        returns (uint256 assets, uint256 shares)
    {
        if (_args.assets == 0 && _args.shares == 0) revert ISilo.ZeroAssets();

        _hookCallBefore(
            _shareStorage,
            Hook.BORROW |
                (_args.leverage ? Hook.LEVERAGE : Hook.NONE) |
                (_args.sameAsset ? Hook.SAME_ASSET : Hook.TWO_ASSETS),
            abi.encodePacked(_args.assets, _args.shares, _args.receiver, _args.borrower)
        );

        (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig,
            ISiloConfig.DebtInfo memory debtInfo
        ) = _shareStorage.siloConfig.accrueInterestAndGetConfigs(
            address(this),
            _args.borrower,
            Hook.BORROW |
                (_args.leverage ? Hook.LEVERAGE : Hook.NONE) |
                (_args.sameAsset ? Hook.SAME_ASSET : Hook.TWO_ASSETS)
        );

        if (!SiloLendingLib.borrowPossible(debtInfo)) revert ISilo.BorrowNotPossible();

        if (!_args.sameAsset) ISilo(collateralConfig.silo).accrueInterest();

        (assets, shares) = SiloLendingLib.borrow(
            debtConfig.debtShareToken,
            debtConfig.token,
            msg.sender,
            _args,
            _totalCollateral.assets,
            _totalDebt
        );

        if (_args.leverage) {
            // change reentrant flag to leverage, to allow for deposit
            _shareStorage.siloConfig.crossNonReentrantBefore(CrossEntrancy.ENTERED_FROM_LEVERAGE);

            bytes32 result = ILeverageBorrower(_args.receiver)
                .onLeverage(msg.sender, _args.borrower, debtConfig.token, assets, _data);

            // allow for deposit reentry only to provide collateral
            if (result != _LEVERAGE_CALLBACK) revert ISilo.LeverageFailed();

            // after deposit, guard is down, for max security we need to enable it again
            _shareStorage.siloConfig.crossNonReentrantBefore(CrossEntrancy.ENTERED);
        }

        if (!debtInfo.sameAsset) {
            collateralConfig.callMaxLtvOracleBeforeQuote();
            debtConfig.callMaxLtvOracleBeforeQuote();
        }

        if (!SiloSolvencyLib.isBelowMaxLtv(
            collateralConfig, debtConfig, _args.borrower, ISilo.AccrueInterestInMemory.No)
        ) {
            revert ISilo.AboveMaxLtv();
        }

        _shareStorage.siloConfig.crossNonReentrantAfter();

        if (collateralConfig.hookReceiver != address(0)) {
            _hookCallAfter(
                _shareStorage,
                collateralConfig.hookReceiver,
                Hook.BORROW |
                    (_args.leverage ? Hook.LEVERAGE : Hook.NONE) |
                    (_args.sameAsset ? Hook.SAME_ASSET : Hook.TWO_ASSETS),
                abi.encodePacked(
                    _args.assets,
                    _args.shares,
                    _args.receiver,
                    _args.borrower,
                    assets,
                    shares
                )
            );
        }
    }

    function repay(
        ISilo.SharedStorage storage _shareStorage,
        uint256 _assets,
        uint256 _shares,
        address _borrower,
        address _repayer,
        bool _liquidation,
        ISilo.Assets storage _totalDebt
    )
        external
        returns (uint256 assets, uint256 shares)
    {
        if (!_liquidation) {
            _hookCallBefore(_shareStorage, Hook.REPAY, abi.encodePacked(_assets, _shares, _borrower, _repayer));
        }

        (
            address debtShareToken,
            address debtAsset,
            address hookReceiver,
            address liquidationModule
        ) = _shareStorage.siloConfig.accrueInterestAndGetConfigOptimised(
            (_liquidation ? Hook.LIQUIDATION : Hook.NONE) | Hook.REPAY, ISilo.CollateralType(0) // type not necessary
        );

        if (_liquidation) {
            if (liquidationModule != msg.sender) revert ISilo.OnlyLiquidationModule();
        }

        (
            assets, shares
        ) = SiloLendingLib.repay(
            IShareToken(debtShareToken), debtAsset, _assets, _shares, _borrower, _repayer, _totalDebt
        );

        if (!_liquidation) {
            _shareStorage.siloConfig.crossNonReentrantAfter();

            if (hookReceiver != address(0)) {
                _hookCallAfter(
                    _shareStorage,
                    hookReceiver,
                    Hook.REPAY,
                    abi.encodePacked(_assets, _shares, _borrower, _repayer, assets, shares)
                );
            }
        }
    }

    // solhint-disable-next-line function-max-lines
    function leverageSameAsset(
        ISilo.SharedStorage storage _shareStorage,
        uint256 _depositAssets,
        uint256 _borrowAssets,
        address _borrower,
        ISilo.CollateralType _collateralType,
        ISilo.Assets storage _totalCollateral,
        ISilo.Assets storage _totalDebt,
        ISilo.Assets storage _totalAssetsForDeposit
    )
        external
        returns (uint256 depositedShares, uint256 borrowedShares)
    {
        if (_depositAssets == 0 || _borrowAssets == 0) revert ISilo.ZeroAssets();

        _hookCallBefore(
            _shareStorage,
            Hook.BORROW | Hook.LEVERAGE | Hook.SAME_ASSET,
            abi.encodePacked(_depositAssets, _borrowAssets, _borrower, _collateralType)
        );

        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;

        { // too deep
            ISiloConfig.DebtInfo memory debtInfo;
            (
                collateralConfig, debtConfig, debtInfo
            ) = _shareStorage.siloConfig.accrueInterestAndGetConfigs(
                address(this),
                _borrower,
                Hook.BORROW | Hook.LEVERAGE | Hook.SAME_ASSET
            );

            if (!SiloLendingLib.borrowPossible(debtInfo)) revert ISilo.BorrowNotPossible();
            if (debtInfo.debtPresent && !debtInfo.sameAsset) revert ISilo.TwoAssetsDebt();
        }

        { // too deep
            (_borrowAssets, borrowedShares) = SiloLendingLib.borrow(
                debtConfig.debtShareToken,
                address(0), // we do not transferring debt
                msg.sender,
                ISilo.BorrowArgs({
                    assets: _borrowAssets,
                    shares: 0,
                    receiver: _borrower,
                    borrower: _borrower,
                    sameAsset: true,
                    leverage: true
                }),
                _totalCollateral.assets,
                _totalDebt
            );

            uint256 requiredCollateral = _borrowAssets * SiloLendingLib._PRECISION_DECIMALS;
            uint256 transferDiff;

            unchecked { requiredCollateral = requiredCollateral / collateralConfig.maxLtv; }
            if (_depositAssets < requiredCollateral) revert ISilo.LeverageTooHigh();

            unchecked {
            // safe because `requiredCollateral` > `_depositAssets`
            // and `_borrowAssets` is chunk of `requiredCollateral`
                transferDiff = _depositAssets - _borrowAssets;
            }

            IERC20(collateralConfig.token).safeTransferFrom(msg.sender, address(this), transferDiff);
        }

        (, depositedShares) = SiloERC4626Lib.deposit(
            address(0), // we do not transferring token
            msg.sender,
            _depositAssets,
            0 /* _shares */,
            _borrower,
            _collateralType == ISilo.CollateralType.Collateral
                ? IShareToken(collateralConfig.collateralShareToken)
                : IShareToken(collateralConfig.protectedShareToken),
            _totalAssetsForDeposit
        );

        _shareStorage.siloConfig.crossNonReentrantAfter();

        if (collateralConfig.hookReceiver != address(0)) {
            _hookCallAfter(
                _shareStorage,
                collateralConfig.hookReceiver,
                Hook.LEVERAGE | Hook.SAME_ASSET,
                abi.encodePacked(
                    _depositAssets, _borrowAssets, _borrower, _collateralType, depositedShares, borrowedShares
                )
            );
        }
    }

    function transitionCollateral(
        ISilo.SharedStorage storage _shareStorage,
        uint256 _shares,
        address _owner,
        ISilo.CollateralType _withdrawType,
        mapping(uint256 assetType => ISilo.Assets) storage _total
    )
        external
        returns (uint256 assets, uint256 toShares)
    {
        _hookCallBefore(
            _shareStorage, Hook.TRANSITION_COLLATERAL, abi.encodePacked(_shares, _owner, _withdrawType, assets)
        );

        ISiloConfig.ConfigData memory collateralConfig = _shareStorage.siloConfig.accrueInterestAndGetConfig(
            address(this), Hook.TRANSITION_COLLATERAL
        );

        uint256 liquidity = _withdrawType == ISilo.CollateralType.Collateral
            ? SiloMathLib.liquidity(_total[AssetTypes.COLLATERAL].assets, _total[AssetTypes.DEBT].assets)
            : _total[AssetTypes.PROTECTED].assets;

        address shareTokenFrom = _withdrawType == ISilo.CollateralType.Collateral
            ? collateralConfig.collateralShareToken
            : collateralConfig.protectedShareToken;

        (assets, _shares) = SiloERC4626Lib.transitionCollateralWithdraw(
            shareTokenFrom,
            _shares,
            _owner,
            msg.sender,
            _withdrawType,
            liquidity,
            _total[uint256(_withdrawType)]
        );

        (ISilo.AssetType depositType, address shareTokenTo) = _withdrawType == ISilo.CollateralType.Collateral
            ? (ISilo.AssetType.Protected, collateralConfig.protectedShareToken)
            : (ISilo.AssetType.Collateral, collateralConfig.collateralShareToken);

        (assets, toShares) = SiloERC4626Lib.deposit(
            address(0), // empty token because we don't want to transfer
            _owner,
            assets,
            0, // shares
            _owner,
            IShareToken(shareTokenTo),
            _total[uint256(depositType)]
        );

        _shareStorage.siloConfig.crossNonReentrantAfter();

        if (collateralConfig.hookReceiver != address(0)) {
            _hookCallAfter(
                _shareStorage,
                collateralConfig.hookReceiver,
                Hook.TRANSITION_COLLATERAL,
                abi.encodePacked(_shares, _owner, _withdrawType, assets)
            );
        }
    }

    function switchCollateralTo(
        ISilo.SharedStorage storage _shareStorage,
        bool _toSameAsset
    ) external {
        _hookCallBefore(_shareStorage, Hook.SWITCH_COLLATERAL, abi.encodePacked(_toSameAsset));

        (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig,
            ISiloConfig.DebtInfo memory debtInfo
        ) = _shareStorage.siloConfig.accrueInterestAndGetConfigs(
            address(this), msg.sender, Hook.SWITCH_COLLATERAL | (_toSameAsset ? Hook.SAME_ASSET : Hook.TWO_ASSETS)
        );

        if (collateralConfig.otherSilo != address(this)) {
            ISilo(collateralConfig.otherSilo).accrueInterest();
        }

        collateralConfig.callSolvencyOracleBeforeQuote();
        debtConfig.callSolvencyOracleBeforeQuote();

        bool msgSenderIsSolvent = SiloSolvencyLib.isSolvent(
            collateralConfig, debtConfig, debtInfo, msg.sender, ISilo.AccrueInterestInMemory.No
        );

        if (!msgSenderIsSolvent) revert ISilo.NotSolvent();

        _shareStorage.siloConfig.crossNonReentrantAfter();

        if (collateralConfig.hookReceiver != address(0)) {
            _hookCallAfter(
                _shareStorage, collateralConfig.hookReceiver, Hook.SWITCH_COLLATERAL, abi.encodePacked(_toSameAsset)
            );
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
        _hookCallBefore(_shareStorage, Hook.FLASH_LOAN, abi.encodePacked(_receiver, _token, _amount));

        ISiloConfig.ConfigData memory config = _shareStorage.siloConfig.getConfig(address(this));

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

        success = true;

        _shareStorage.siloConfig.crossNonReentrantAfter();

        if (config.hookReceiver != address(0)) {
            _hookCallAfter(
                _shareStorage,
                config.hookReceiver,
                Hook.FLASH_LOAN,
                abi.encodePacked(_receiver, _token, _amount, success)
            );
        }
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

        IPartialLiquidation(cfg.liquidationModule).synchronizeHooks(cfg.hookReceiver, hooksBefore, hooksAfter);
    }

    function _hookCallBefore(ISilo.SharedStorage storage _shareStorage, uint256 _action, bytes memory _data)
        private
    {
        // check hooks first, because it is the same slot as siloConfig, and siloConfig was used already
        if (!_shareStorage.hooksBefore.matchAction(_action)) return;

        IHookReceiver hookReceiver = _shareStorage.hookReceiver;
        if (address(hookReceiver) == address(0)) return;

        // there should be no hook calls, if you inside action eg inside leverage, liquidation etc
        hookReceiver.beforeAction(address(this), _action, _data);
    }

    function _hookCallAfter(
        ISilo.SharedStorage storage _shareStorage,
        address hookReceiverCached,
        uint256 _action,
        bytes memory _data
    ) private {
        if (!_shareStorage.hooksAfter.matchAction(_action)) return;

        IHookReceiver(hookReceiverCached).afterAction(address(this), _action, _data);
    }
}
