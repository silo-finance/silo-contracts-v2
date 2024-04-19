// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {IERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {ISilo} from "../interfaces/ISilo.sol";
import {ISiloOracle} from "../interfaces/ISiloOracle.sol";
import {IShareToken} from "../interfaces/IShareToken.sol";
import {ILeverageBorrower} from "../interfaces/ILeverageBorrower.sol";
import {IERC3156FlashBorrower} from "../interfaces/IERC3156FlashBorrower.sol";
import {IHookReceiver} from "../utils/hook-receivers/interfaces/IHookReceiver.sol";

import {SiloERC4626Lib} from "./SiloERC4626Lib.sol";
import {SiloSolvencyLib} from "./SiloSolvencyLib.sol";
import {SiloLendingLib} from "./SiloLendingLib.sol";
import {SiloStdLib} from "./SiloStdLib.sol";
import {CrossEntrancy} from "./CrossEntrancy.sol";
import {Methods} from "./Methods.sol";
import {Hook} from "./Hook.sol";

library Actions {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using Hook for IHookReceiver;

    bytes32 internal constant _LEVERAGE_CALLBACK = keccak256("ILeverageBorrower.onLeverage");
    bytes32 internal constant _FLASHLOAN_CALLBACK = keccak256("ERC3156FlashBorrower.onFlashLoan");

    error FeeOverflow();

    function deposit(
        ISiloConfig _siloConfig,
ISilo.Assets storage _totalCollateral

uint256 _assets,
        uint256 _shares,
        address _receiver,
        ISilo.AssetType _assetType,
        ISilo.Assets storage _totalCollateral
    )
        external
        returns (uint256 assets, uint256 shares)
    {
        if (_assetType == ISilo.AssetType.Debt) revert ISilo.WrongAssetType();

        (
            ISiloConfig.ConfigData memory collateralConfig,,
        ) = _siloConfig.startAction(
            address(0) /* no borrower */, Hook.DEPOSIT, abi.encodePacked(_assets, _shares, _receiver, _assetType)
        );

        address collateralShareToken = _assetType == ISilo.AssetType.Collateral
            ? collateralConfig.collateralShareToken
            : collateralConfig.protectedShareToken;

        (assets, shares) = SiloERC4626Lib.deposit(
            collateralConfig.token,
            msg.sender,
            _assets,
            _shares,
            _receiver,
            IShareToken(collateralShareToken),
            _totalCollateral
        );

        IHookReceiver hookAfter = _siloConfig.finishAction(address(this), Hook.DEPOSIT);

        if (address(hookAfter) != address(0)) {
            hookAfter.afterActionCall(
                Hook.DEPOSIT,
                abi.encodePacked(_assets, _shares, _receiver, _assetType, assets, shares)
            );
        }
    }

    // solhint-disable-next-line function-max-lines, code-complexity
    function withdraw(ISiloConfig _siloConfig, ISilo.WithdrawArgs calldata _args, ISilo.Assets storage _totalAssets)
        external
        returns (uint256 assets, uint256 shares)
    {
        if (_args.assetType == ISilo.AssetType.Debt) revert ISilo.WrongAssetType();

        (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig,
            ISiloConfig.DebtInfo memory debtInfo
        ) = _siloConfig.startAction(
            _args.owner,
            Hook.WITHDRAW,
            abi.encodePacked(_args.assets, _args.shares, _args.receiver, _args.owner, _args.spender, _args.assetType)
        );

        if (collateralConfig.silo != debtConfig.silo) ISilo(debtConfig.silo).accrueInterest();

        // this if helped with Stack too deep
        if (_args.assetType == ISilo.AssetType.Collateral) {
            (assets, shares) = SiloERC4626Lib.withdraw(
                collateralConfig.token,
                collateralConfig.collateralShareToken,
                _args.assets,
                _args.shares,
                _args.receiver,
                _args.owner,
                _args.spender,
                _args.assetType,
                ISilo(collateralConfig.silo).getRawLiquidity(),
                _totalAssets
            );
        } else {
            (assets, shares) = SiloERC4626Lib.withdraw(
                collateralConfig.token,
                collateralConfig.protectedShareToken,
                _args.assets,
                _args.shares,
                _args.receiver,
                _args.owner,
                _args.spender,
                _args.assetType,
                _totalAssets.assets,
                _totalAssets
            );
        }

        if (SiloSolvencyLib.depositWithoutDebt(debtInfo)) {
            IHookReceiver hookAfter = _siloConfig.finishAction(address(this), Hook.WITHDRAW);

            if (address(hookAfter) != address(0)) {
                hookAfter.afterActionCall(
                    Hook.WITHDRAW,
                    abi.encodePacked(
                        _args.assets,
                        _args.shares,
                        _args.receiver,
                        _args.owner,
                        _args.spender,
                        _args.assetType,
                        assets,
                        shares
                    )
                );
            }

            return (assets, shares);
        }

        if (collateralConfig.callBeforeQuote) {
            ISiloOracle(collateralConfig.solvencyOracle).beforeQuote(collateralConfig.token);
        }

        if (debtConfig.callBeforeQuote) {
            ISiloOracle(debtConfig.solvencyOracle).beforeQuote(debtConfig.token);
        }

        // `_args.owner` must be solvent
        if (!SiloSolvencyLib.isSolvent(
            collateralConfig, debtConfig, debtInfo, _args.owner, ISilo.AccrueInterestInMemory.No
        )) revert ISilo.NotSolvent();

        {
            IHookReceiver hookAfter = _siloConfig.finishAction(address(this), Hook.WITHDRAW);

            if (address(hookAfter) != address(0)) {
                hookAfter.afterActionCall(
                    Hook.WITHDRAW |
                        (_args.assetType == ISilo.AssetType.Collateral ? Hook.COLLATERAL_TOKEN : Hook.PROTECTED_TOKEN),
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
    }

    // solhint-disable-next-line function-max-lines, code-complexity
    function borrow(
        ISiloConfig _siloConfig,
        ISilo.BorrowArgs memory _args,
        ISilo.Assets storage _totalDebt,
        bytes memory _data
    )
        external
        returns (uint256 assets, uint256 shares)
    {
        if (_args.assets == 0 && _args.shares == 0) revert ISilo.ZeroAssets();

        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;

        { // too deep
            ISiloConfig.DebtInfo memory debtInfo;

            (collateralConfig, debtConfig, debtInfo) = _siloConfig.startAction(
                _args.borrower,
                (_args.leverage ? Hook.LEVERAGE : Hook.BORROW) | (_args.sameAsset ? Hook.SAME_ASSET : Hook.TWO_ASSETS),
                abi.encodePacked(
                    _args.assets,
                    _args.shares,
                    _args.receiver,
                    _args.borrower
                )
            );

            if (!SiloLendingLib.borrowPossible(debtInfo)) revert ISilo.BorrowNotPossible();

            if (debtConfig.silo != collateralConfig.silo) ISilo(collateralConfig.silo).accrueInterest();
        }

        (assets, shares) = SiloLendingLib.borrow(
            debtConfig.debtShareToken,
            debtConfig.token,
            msg.sender,
            _args,
            _totalDebt
        );

        if (_args.leverage) {
            // change reentrant flag to leverage, to allow for deposit
            _siloConfig.crossLeverageGuard(CrossEntrancy.ENTERED_FROM_LEVERAGE);

            bytes32 result = ILeverageBorrower(_args.receiver)
                .onLeverage(msg.sender, _args.borrower, debtConfig.token, assets, _data);

            // allow for deposit reentry only to provide collateral
            if (result != _LEVERAGE_CALLBACK) revert ISilo.LeverageFailed();

            // after deposit, guard is down, for max security we need to enable it again
            _siloConfig.crossLeverageGuard(CrossEntrancy.ENTERED);
        }

        if (collateralConfig.callBeforeQuote) {
            ISiloOracle(collateralConfig.maxLtvOracle).beforeQuote(collateralConfig.token);
        }

        if (debtConfig.callBeforeQuote) {
            ISiloOracle(debtConfig.maxLtvOracle).beforeQuote(debtConfig.token);
        }

        if (!SiloSolvencyLib.isBelowMaxLtv(
            collateralConfig, debtConfig, _args.borrower, ISilo.AccrueInterestInMemory.No)
        ) {
            revert ISilo.AboveMaxLtv();
        }

        IHookReceiver hookAfter = _siloConfig.finishAction(address(this), Hook.WITHDRAW);

        if (address(hookAfter) != address(0)) {
            hookAfter.afterActionCall(
                (_args.leverage ? Hook.LEVERAGE : Hook.BORROW) | (_args.sameAsset ? Hook.SAME_ASSET : Hook.TWO_ASSETS),
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
        ISiloConfig _siloConfig,
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
        (
            ISiloConfig.ConfigData memory collateralConfig,,
        ) = _siloConfig.startAction(
            address(0) /* no borrower */,
            Hook.REPAY,
            abi.encodePacked(_assets, _shares, _borrower, _repayer)
        );

        if (_liquidation && collateralConfig.liquidationModule != msg.sender) revert ISilo.OnlyLiquidationModule();

        (
            assets, shares
        ) = SiloLendingLib.repay(collateralConfig, _assets, _shares, _borrower, _repayer, _totalDebt);

        if (!_liquidation) {
            IHookReceiver hookAfter = _siloConfig.finishAction(address(this), Hook.REPAY);

            if (address(hookAfter) != address(0)) {
                hookAfter.afterActionCall(
                    Hook.REPAY,
                    abi.encodePacked(_assets, _shares, _borrower, _repayer, assets, shares)
                );
            }
        }
    }

    // solhint-disable-next-line function-max-lines
    function leverageSameAsset(
        ISiloConfig _siloConfig,
        uint256 _depositAssets,
        uint256 _borrowAssets,
        address _borrower,
        ISilo.AssetType _assetType,
        uint256 _totalCollateralAssets,
        ISilo.Assets storage _totalDebt,
        ISilo.Assets storage _totalAssetsForDeposit
    )
        external
        returns (uint256 depositedShares, uint256 borrowedShares)
    {
        if (_depositAssets == 0 || _borrowAssets == 0) revert ISilo.ZeroAssets();

        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;

        { // too deep
            ISiloConfig.DebtInfo memory debtInfo;
            (
                collateralConfig, debtConfig, debtInfo
            ) = _siloConfig.startAction(
                _borrower,
                Hook.LEVERAGE | Hook.SAME_ASSET,
                abi.encodePacked(_depositAssets, _borrowAssets, _borrower, _assetType)
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
                    leverage: true,
                    totalCollateralAssets: _totalCollateralAssets
                }),
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

            IERC20Upgradeable(collateralConfig.token).safeTransferFrom(msg.sender, address(this), transferDiff);
        }

        (, depositedShares) = SiloERC4626Lib.deposit(
            address(0), // we do not transferring token
            msg.sender,
            _depositAssets,
            0 /* _shares */,
            _borrower,
            _assetType == ISilo.AssetType.Collateral
                ? IShareToken(collateralConfig.collateralShareToken)
                : IShareToken(collateralConfig.protectedShareToken),
            _totalAssetsForDeposit
        );

        IHookReceiver hookAfter = _siloConfig.finishAction(address(this), Hook.LEVERAGE | Hook.SAME_ASSET);

        if (address(hookAfter) != address(0)) {
            hookAfter.afterActionCall(
                Hook.LEVERAGE | Hook.SAME_ASSET,
                abi.encodePacked(_depositAssets, _borrowAssets, _borrower, _assetType, depositedShares, borrowedShares)
            );
        }
    }

    function transitionCollateral(
        ISiloConfig _siloConfig,
        uint256 _shares,
        address _owner,
        ISilo.AssetType _withdrawType,
        mapping(ISilo.AssetType => ISilo.Assets) storage _total
    )
        external
        returns (uint256 assets, uint256 toShares)
    {
        if (_withdrawType == ISilo.AssetType.Debt) revert ISilo.WrongAssetType();

        (
            ISiloConfig.ConfigData memory collateralConfig,,
        ) = _siloConfig.startAction(
            _owner, Hook.TRANSITION_COLLATERAL, abi.encodePacked(_shares, _owner, _withdrawType, assets)
        );

        (address shareTokenFrom, uint256 liquidity) = _withdrawType == ISilo.AssetType.Collateral
            ? (collateralConfig.collateralShareToken, ISilo(address(this)).getRawLiquidity())
            : (collateralConfig.protectedShareToken, _total[ISilo.AssetType.Protected].assets);

        (assets, _shares) = SiloERC4626Lib.transitionCollateralWithdraw(
            shareTokenFrom,
            _shares,
            _owner,
            msg.sender,
            _withdrawType,
            liquidity,
            _total[_withdrawType]
        );

        (ISilo.AssetType depositType, address shareTokenTo) = _withdrawType == ISilo.AssetType.Collateral
            ? (ISilo.AssetType.Protected, collateralConfig.protectedShareToken)
            : (ISilo.AssetType.Collateral, collateralConfig.collateralShareToken);

        (assets, toShares) = SiloERC4626Lib.deposit(
            address(0), // empty token because we don't want to transfer
            _owner,
            assets,
            0, // shares
            _owner,
            IShareToken(shareTokenTo),
            _total[depositType]
        );

        IHookReceiver hookAfter = _siloConfig.finishAction(address(this), Hook.TRANSITION_COLLATERAL);

        if (address(hookAfter) != address(0)) {
            hookAfter.afterActionCall(
                Hook.TRANSITION_COLLATERAL,
                abi.encodePacked(_shares, _owner, _withdrawType, assets)
            );
        }
    }

    function switchCollateralTo(ISiloConfig _siloConfig, bool _sameAsset) external {
        (
            ISiloConfig.ConfigData memory collateral,
            ISiloConfig.ConfigData memory debt,
            ISiloConfig.DebtInfo memory debtInfo
        ) = _siloConfig.startAction(msg.sender, Hook.SWITCH_COLLATERAL, abi.encodePacked(_sameAsset));

        ISilo(collateral.otherSilo).accrueInterest();

        if (!SiloSolvencyLib.isSolvent(collateral, debt, debtInfo, msg.sender, ISilo.AccrueInterestInMemory.No)) {
            revert ISilo.NotSolvent();
        }

        IHookReceiver hookAfter = _siloConfig.finishAction(address(this), Hook.SWITCH_COLLATERAL);

        if (address(hookAfter) != address(0)) {
            hookAfter.afterActionCall(Hook.SWITCH_COLLATERAL, abi.encodePacked(_sameAsset));
        }
    }

    /// @notice Executes a flash loan, sending the requested amount to the receiver and expecting it back with a fee
    /// @param _siloConfig Configuration data relevant to the silo asset borrowed
    /// @param _receiver The entity that will receive the flash loan and is expected to return it with a fee
    /// @param _token The token that is being borrowed in the flash loan
    /// @param _amount The amount of tokens to be borrowed
    /// @param _siloData Storage containing data related to fees
    /// @param _data Additional data to be passed to the flash loan receiver
    /// @return success A boolean indicating if the flash loan was successful
    function flashLoan(
        ISiloConfig _siloConfig,
        IERC3156FlashBorrower _receiver,
        address _token,
        uint256 _amount,
        ISilo.SiloData storage _siloData,
        bytes calldata _data
    )
        external
        returns (bool success)
    {
        _siloConfig.startAction(
            address(0) /* not a borrower */,
            Hook.FLASH_LOAN,
            abi.encodePacked(_receiver, _token, _amount)
        );

        // flashFee will revert for wrong token
        uint256 fee = SiloStdLib.flashFee(_siloConfig, _token, _amount);
        if (fee > type(uint192).max) revert FeeOverflow();

        IERC20Upgradeable(_token).safeTransfer(address(_receiver), _amount);

        if (_receiver.onFlashLoan(msg.sender, _token, _amount, fee, _data) != _FLASHLOAN_CALLBACK) {
            revert ISilo.FlashloanFailed();
        }

        IERC20Upgradeable(_token).safeTransferFrom(address(_receiver), address(this), _amount + fee);

        // cast safe, because we checked `fee > type(uint192).max`
        _siloData.daoAndDeployerFees += uint192(fee);

        success = true;

        IHookReceiver hookAfter = _siloConfig.finishAction(address(this), Hook.FLASH_LOAN);

        if (address(hookAfter) != address(0)) {
            hookAfter.afterActionCall(
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
    function withdrawFees(ISilo _silo, ISilo.SiloData storage _siloData) external {
        (
            address daoFeeReceiver,
            address deployerFeeReceiver,
            uint256 daoFee,
            uint256 deployerFee,
            address asset
        ) = SiloStdLib.getFeesAndFeeReceiversWithAsset(_silo);

        uint256 earnedFees = _siloData.daoAndDeployerFees;
        uint256 balanceOf = IERC20Upgradeable(asset).balanceOf(address(this));
        if (balanceOf == 0) revert ISilo.BalanceZero();

        if (earnedFees > balanceOf) earnedFees = balanceOf;
        if (earnedFees == 0) revert ISilo.EarnedZero();

        // we will never underflow because earnedFees max value is `_siloData.daoAndDeployerFees`
        unchecked { _siloData.daoAndDeployerFees -= uint192(earnedFees); }

        if (daoFeeReceiver == address(0) && deployerFeeReceiver == address(0)) {
            // just in case, should never happen...
            revert ISilo.NothingToPay();
        } else if (deployerFeeReceiver == address(0)) {
            // deployer was never setup or deployer NFT has been burned
            IERC20Upgradeable(asset).safeTransfer(daoFeeReceiver, earnedFees);
        } else if (daoFeeReceiver == address(0)) {
            // should never happen... but we assume DAO does not want to make money so all is going to deployer
            IERC20Upgradeable(asset).safeTransfer(deployerFeeReceiver, earnedFees);
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

            IERC20Upgradeable(asset).safeTransfer(daoFeeReceiver, daoFees);
            IERC20Upgradeable(asset).safeTransfer(deployerFeeReceiver, deployerFees);
        }
    }

    function updateHooks(
        ISiloConfig _siloConfig,
        ISilo.SharedStorage storage _sharedStorage,
        uint24 _silo0HooksBefore,
        uint24 _silo0HooksAfter,
        uint24 _silo1HooksBefore,
        uint24 _silo1HooksAfter
    ) external {
        (
            ISiloConfig.ConfigData memory cfg0, ISiloConfig.ConfigData memory cfg1,
        ) = _siloConfig.getConfigs(address(this), address(0) /* no borrower */, 0);

        if (msg.sender != cfg0.hookReceiver) revert ISilo.OnlyHookReceiver();

        _sharedStorage.silo0HooksBefore = _silo0HooksBefore;
        _sharedStorage.silo0HooksAfter = _silo0HooksAfter;
        _sharedStorage.silo1HooksBefore = _silo1HooksBefore;
        _sharedStorage.silo1HooksAfter = _silo1HooksAfter;

        IShareToken(cfg0.collateralShareToken).synchronizeHooks(
            cfg0.hookReceiver, _silo0HooksBefore, _silo0HooksAfter, Hook.COLLATERAL_TOKEN
        );
        IShareToken(cfg0.protectedShareToken).synchronizeHooks(
            cfg0.hookReceiver, _silo0HooksBefore, _silo0HooksAfter, Hook.PROTECTED_TOKEN
        );
        IShareToken(cfg0.debtShareToken).synchronizeHooks(
            cfg0.hookReceiver, _silo0HooksBefore, _silo0HooksAfter, Hook.DEBT_TOKEN
        );

        IShareToken(cfg0.collateralShareToken).synchronizeHooks(
            cfg1.hookReceiver, _silo1HooksBefore, _silo1HooksAfter, Hook.COLLATERAL_TOKEN
        );
        IShareToken(cfg1.protectedShareToken).synchronizeHooks(
            cfg1.hookReceiver, _silo1HooksBefore, _silo1HooksAfter, Hook.PROTECTED_TOKEN
        );
        IShareToken(cfg1.debtShareToken).synchronizeHooks(
            cfg1.hookReceiver, _silo1HooksBefore, _silo1HooksAfter, Hook.DEBT_TOKEN
        );
    }
}
