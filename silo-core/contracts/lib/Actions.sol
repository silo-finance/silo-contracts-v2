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
import {IPartialLiquidation} from "../interfaces/IPartialLiquidation.sol";
import {IHookReceiver} from "../utils/hook-receivers/interfaces/IHookReceiver.sol";

import {SiloERC4626Lib} from "./SiloERC4626Lib.sol";
import {SiloSolvencyLib} from "./SiloSolvencyLib.sol";
import {SiloLendingLib} from "./SiloLendingLib.sol";
import {SiloStdLib} from "./SiloStdLib.sol";
import {CrossEntrancy} from "./CrossEntrancy.sol";
import {Hook} from "./Hook.sol";
import {ConfigLib} from "./ConfigLib.sol";

library Actions {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using Hook for uint256;
    using Hook for uint24;

    bytes32 internal constant _LEVERAGE_CALLBACK = keccak256("ILeverageBorrower.onLeverage");
    bytes32 internal constant _FLASHLOAN_CALLBACK = keccak256("ERC3156FlashBorrower.onFlashLoan");

    error FeeOverflow();

    // when using .startAction: expected 188000 got 198932 it is more by 10932
    // when using _config in param: expected 188000 got 188200 it is more by 200
    // when using one config and pass as args: expected 188000 got 186093 it is less by 1907
    // when accrue interest from config contract and pass config address: expected 188000 got 184314 it is less by 3686
    function deposit(
        ISilo.SharedStorage storage _shareStorage,
        uint256 _assets,
        uint256 _shares,
        address _receiver,
        ISilo.AssetType _assetType,
        ISilo.Assets storage _totalCollateral
    )
        external
        returns (uint256 assets, uint256 shares)
    {
        _hookCallBefore(_shareStorage, Hook.DEPOSIT, abi.encodePacked(_assets, _shares, _receiver, _assetType));

        ISiloConfig.ConfigData memory _collateralConfig = _shareStorage.siloConfig.getConfigAndAccrue(
            address(this), Hook.DEPOSIT
        );

        if (_assetType == ISilo.AssetType.Debt) revert ISilo.WrongAssetType();

        address collateralShareToken = _assetType == ISilo.AssetType.Collateral
            ? _collateralConfig.collateralShareToken
            : _collateralConfig.protectedShareToken;

        (assets, shares) = SiloERC4626Lib.deposit(
            _collateralConfig.token,
            msg.sender,
            _assets,
            _shares,
            _receiver,
            IShareToken(collateralShareToken),
            _totalCollateral
        );

        _shareStorage.siloConfig.crossNonReentrantAfter();

        _hookCallAfter(
            _shareStorage, Hook.DEPOSIT, abi.encodePacked(_assets, _shares, _receiver, _assetType, assets, shares)
        );
    }

    // startAction: expected 176906 got 199694 it is more by 22788
    // getConfigsAndAccrue: expected 176906 got 192410 it is more by 15504
    // getConfigsAndAccrue + HOOK address check: expected 176906 got 191271 it is more by 14365
    // getConfigsAndAccrue + HOOK address check + lib for ordering: expected 176906 got 195179 it is more by 18273
    // getConfigsAndAccrue + HOOK address check + lib for ordering using UINT: expected 176906 got 148652 it is less by 28254
    function withdraw(
        ISilo.SharedStorage storage _shareStorage,
        ISilo.WithdrawArgs calldata _args,
        ISilo.Assets storage _totalAssets
    )
        external
        returns (uint256 assets, uint256 shares)
    {
        if (_args.assetType == ISilo.AssetType.Debt) revert ISilo.WrongAssetType();

        _hookCallBeforeWithdraw(_shareStorage, _args);

        (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig,
            ISiloConfig.DebtInfo memory debtInfo
        ) = _shareStorage.siloConfig.getConfigsAndAccrue(address(this), Hook.WITHDRAW, _args.owner);

        if (collateralConfig.silo != debtConfig.silo) ISilo(debtConfig.silo).accrueInterest();

        (assets, shares) = _siloERC4626LibWithdraw(collateralConfig, _args, _totalAssets);

        if (SiloSolvencyLib.depositWithoutDebt(debtInfo)) {
            _shareStorage.siloConfig.crossNonReentrantAfter();

            if (collateralConfig.hookReceiver != address(0)) {
                _hookCallAfterWithdraw(_shareStorage, _args, assets, shares);
            }

            return (assets, shares);
        }

        _callBeforeQuoteOnWithdraw(collateralConfig, debtConfig);

        // `_args.owner` must be solvent
        if (!SiloSolvencyLib.isSolvent(
            collateralConfig, debtConfig, debtInfo, _args.owner, ISilo.AccrueInterestInMemory.No
        )) revert ISilo.NotSolvent();

        _shareStorage.siloConfig.crossNonReentrantAfter();

        if (collateralConfig.hookReceiver != address(0)) {
            _hookCallAfterWithdraw(_shareStorage, _args, assets, shares);
        }
    }

    // solhint-disable-next-line function-max-lines, code-complexity
    function borrow(
        ISilo.SharedStorage storage _shareStorage,
        ISilo.BorrowArgs memory _args,
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

        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;

        { // too deep
            ISiloConfig.DebtInfo memory debtInfo;

            (collateralConfig, debtConfig, debtInfo) = _shareStorage.siloConfig.getConfigsAndAccrue(
                address(this),
                Hook.BORROW |
                    (_args.leverage ? Hook.LEVERAGE : Hook.NONE) |
                    (_args.sameAsset ? Hook.SAME_ASSET : Hook.TWO_ASSETS),
                _args.borrower
            );

            if (!SiloLendingLib.borrowPossible(debtInfo)) revert ISilo.BorrowNotPossible();

            if (!_args.sameAsset) ISilo(collateralConfig.silo).accrueInterest();
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
            _shareStorage.siloConfig.crossNonReentrantBefore(CrossEntrancy.ENTERED_FROM_LEVERAGE);

            bytes32 result = ILeverageBorrower(_args.receiver)
                .onLeverage(msg.sender, _args.borrower, debtConfig.token, assets, _data);

            // allow for deposit reentry only to provide collateral
            if (result != _LEVERAGE_CALLBACK) revert ISilo.LeverageFailed();

            // after deposit, guard is down, for max security we need to enable it again
            _shareStorage.siloConfig.crossNonReentrantBefore(CrossEntrancy.ENTERED);
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

        _shareStorage.siloConfig.crossNonReentrantAfter();

        if (collateralConfig.hookReceiver != address(0)) {
            _hookCallAfter(
                _shareStorage,
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
            ,ISiloConfig.ConfigData memory debtConfig,
        ) = _shareStorage.siloConfig.getConfigsAndAccrue(
            address(this),
            (_liquidation ? Hook.LIQUIDATION : Hook.NONE) | Hook.REPAY,
            _borrower
        );

        if (_liquidation) {
            if (debtConfig.liquidationModule != msg.sender) revert ISilo.OnlyLiquidationModule();
        }

        (
            assets, shares
        ) = SiloLendingLib.repay(debtConfig, _assets, _shares, _borrower, _repayer, _totalDebt);

        if (!_liquidation) {
            _shareStorage.siloConfig.crossNonReentrantAfter();

            if (debtConfig.hookReceiver != address(0)) {
                _hookCallAfter(
                    _shareStorage,
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
        ISilo.AssetType _assetType,
        uint256 _totalCollateralAssets,
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
            abi.encodePacked(_depositAssets, _borrowAssets, _borrower, _assetType)
        );

        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;

        { // too deep
            ISiloConfig.DebtInfo memory debtInfo;
            (
                collateralConfig, debtConfig, debtInfo
            ) = _shareStorage.siloConfig.getConfigsAndAccrue(
                address(this),
                Hook.BORROW | Hook.LEVERAGE | Hook.SAME_ASSET,
                _borrower
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

        _shareStorage.siloConfig.crossNonReentrantAfter();

        if (collateralConfig.hookReceiver != address(0)) {
            _hookCallAfter(
                _shareStorage,
                Hook.LEVERAGE | Hook.SAME_ASSET,
                abi.encodePacked(_depositAssets, _borrowAssets, _borrower, _assetType, depositedShares, borrowedShares)
            );
        }
    }

    function transitionCollateral(
        ISilo.SharedStorage storage _shareStorage,
        uint256 _shares,
        address _owner,
        ISilo.AssetType _withdrawType,
        mapping(ISilo.AssetType => ISilo.Assets) storage _total
    )
        external
        returns (uint256 assets, uint256 toShares)
    {
        if (_withdrawType == ISilo.AssetType.Debt) revert ISilo.WrongAssetType();

        _hookCallBefore(
            _shareStorage, Hook.TRANSITION_COLLATERAL, abi.encodePacked(_shares, _owner, _withdrawType, assets)
        );

        ISiloConfig.ConfigData memory collateralConfig = _shareStorage.siloConfig.getConfigAndAccrue(
            address(this), Hook.TRANSITION_COLLATERAL
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

        _shareStorage.siloConfig.crossNonReentrantAfter();

        if (collateralConfig.hookReceiver != address(0)) {
            _hookCallAfter(
                _shareStorage,
                Hook.TRANSITION_COLLATERAL,
                abi.encodePacked(_shares, _owner, _withdrawType, assets)
            );
        }
    }

    function switchCollateralTo(
        ISilo.SharedStorage storage _shareStorage,
        bool _sameAsset
    ) external {
        _hookCallBefore(_shareStorage, Hook.SWITCH_COLLATERAL, abi.encodePacked(_sameAsset));

        (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig,
            ISiloConfig.DebtInfo memory debtInfo
        ) = _shareStorage.siloConfig.getConfigsAndAccrue(
            address(this), Hook.SWITCH_COLLATERAL | (_sameAsset ? Hook.SAME_ASSET : Hook.TWO_ASSETS), msg.sender
        );

        if (collateralConfig.otherSilo != address(this)) {
            ISilo(collateralConfig.otherSilo).accrueInterest();
        }

        if (!SiloSolvencyLib.isSolvent(
            collateralConfig, debtConfig, debtInfo, msg.sender, ISilo.AccrueInterestInMemory.No)
        ) {
            revert ISilo.NotSolvent();
        }

        _shareStorage.siloConfig.crossNonReentrantAfter();

        if (collateralConfig.hookReceiver != address(0)) {
            _hookCallAfter(_shareStorage, Hook.SWITCH_COLLATERAL, abi.encodePacked(_sameAsset));
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

        IERC20Upgradeable(_token).safeTransfer(address(_receiver), _amount);

        if (_receiver.onFlashLoan(msg.sender, _token, _amount, fee, _data) != _FLASHLOAN_CALLBACK) {
            revert ISilo.FlashloanFailed();
        }

        IERC20Upgradeable(_token).safeTransferFrom(address(_receiver), address(this), _amount + fee);

        // cast safe, because we checked `fee > type(uint192).max`
        _siloData.daoAndDeployerFees += uint192(fee);

        success = true;

        _shareStorage.siloConfig.crossNonReentrantAfter();

        if (config.hookReceiver != address(0)) {
            _hookCallAfter(
                _shareStorage,
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
        ISilo.SharedStorage storage _sharedStorage,
        uint24 _hooksBefore,
        uint24 _hooksAfter
    ) external {
        ISiloConfig.ConfigData memory cfg = _sharedStorage.siloConfig.getConfig(address(this));

        if (msg.sender != cfg.hookReceiver) revert ISilo.OnlyHookReceiver();

        _sharedStorage.hooksBefore = _hooksBefore;
        _sharedStorage.hooksAfter = _hooksAfter;
        _sharedStorage.hookReceiver = IHookReceiver(msg.sender);

        IShareToken(cfg.collateralShareToken).synchronizeHooks(
            cfg.hookReceiver, _hooksBefore, _hooksAfter, uint24(Hook.COLLATERAL_TOKEN)
        );

        IShareToken(cfg.protectedShareToken).synchronizeHooks(
            cfg.hookReceiver, _hooksBefore, _hooksAfter, uint24(Hook.PROTECTED_TOKEN)
        );

        IShareToken(cfg.debtShareToken).synchronizeHooks(
            cfg.hookReceiver, _hooksBefore, _hooksAfter, uint24(Hook.DEBT_TOKEN)
        );

        IPartialLiquidation(cfg.liquidationModule).synchronizeHooks(cfg.hookReceiver, _hooksBefore, _hooksAfter);
    }

    function _hookCallBefore(ISilo.SharedStorage storage _shareStorage, uint256 _action, bytes memory _data)
        private
    {
        // check hooks first, because it is the same slot as siloConfig, and siloConfig was used already
        if (!_shareStorage.hooksBefore.matchAction(_action)) return;

        IHookReceiver hookReceiver = _shareStorage.hookReceiver;
        if (address(hookReceiver) == address(0)) return;

        // there should be no hook calls, if you inside action eg inside leverage, liquidation etc
        // TODO make sure we good inside leverage
        hookReceiver.beforeAction(address(this), _action, _data);
    }

    function _hookCallAfter(ISilo.SharedStorage storage _shareStorage, uint256 _action, bytes memory _data)
        private
    {
        // check hooks first, because it is the same slot as siloConfig, and siloConfig was used already
        if (!_shareStorage.hooksAfter.matchAction(_action)) return;

        IHookReceiver hookReceiver = _shareStorage.hookReceiver;
        if (address(hookReceiver) == address(0)) return;

        hookReceiver.afterAction(address(this), _action, _data);
    }

    function _hookCallBeforeWithdraw(
        ISilo.SharedStorage storage _shareStorage,
        ISilo.WithdrawArgs calldata _args
    ) private {
        _hookCallBefore(
            _shareStorage,
            Hook.WITHDRAW |
                (_args.assetType == ISilo.AssetType.Collateral ? Hook.COLLATERAL_TOKEN : Hook.PROTECTED_TOKEN),
            abi.encodePacked(_args.assets, _args.shares, _args.receiver, _args.owner, _args.spender, _args.assetType)
        );
    }

    function _hookCallAfterWithdraw(
        ISilo.SharedStorage storage _shareStorage,
        ISilo.WithdrawArgs calldata _args,
        uint256 assets,
        uint256 shares
    ) private {
        _hookCallAfter(
            _shareStorage,
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

    function _siloERC4626LibWithdraw(
        ISiloConfig.ConfigData memory collateralConfig,
        ISilo.WithdrawArgs calldata _args,
        ISilo.Assets storage _totalAssets
    ) private returns (uint256 assets, uint256 shares) {
        address shareToken = _args.assetType == ISilo.AssetType.Collateral
                ? collateralConfig.collateralShareToken
                : collateralConfig.protectedShareToken;

        uint256 liquidity = _args.assetType == ISilo.AssetType.Collateral
            ? ISilo(address(this)).getRawLiquidity()
            : _totalAssets.assets;

        (assets, shares) = SiloERC4626Lib.withdraw(
            collateralConfig.token,
            shareToken,
            _args.assets,
            _args.shares,
            _args.receiver,
            _args.owner,
            _args.spender,
            _args.assetType,
            liquidity,
            _totalAssets
        );
    }

    function _callBeforeQuoteOnWithdraw(
        ISiloConfig.ConfigData memory collateralConfig,
        ISiloConfig.ConfigData memory debtConfig
    ) private {
        if (collateralConfig.callBeforeQuote) {
            ISiloOracle(collateralConfig.solvencyOracle).beforeQuote(collateralConfig.token);
        }

        if (debtConfig.callBeforeQuote) {
            ISiloOracle(debtConfig.solvencyOracle).beforeQuote(debtConfig.token);
        }
    }
}
