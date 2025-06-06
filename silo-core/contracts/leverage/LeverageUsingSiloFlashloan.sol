// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {IERC20Permit} from "openzeppelin5/token/ERC20/extensions/IERC20Permit.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";

import {TransientReentrancy} from "../hooks/_common/TransientReentrancy.sol";

import {RevertLib} from "../lib/RevertLib.sol";

import {ISilo} from "../interfaces/ISilo.sol";
import {ILeverageUsingSiloFlashloan} from "../interfaces/ILeverageUsingSiloFlashloan.sol";
import {IERC3156FlashBorrower} from "../interfaces/IERC3156FlashBorrower.sol";
import {IERC3156FlashLender} from "../interfaces/IERC3156FlashLender.sol";
import {IWrappedNativeToken} from "../interfaces/IWrappedNativeToken.sol";

import {RevenueModule} from "./modules/RevenueModule.sol";
import {LeverageTxState} from "./modules/LeverageTxState.sol";

// TODO add example what means leverage 2x

// TODO same asset leverage in phase 2
// TODO events on state changes or action that we need to track
// TODO ensure it will that work for Pendle (show test)
// TODO triple check approvals
//- Leverage contract should never have any tokens
//- close should repay all debt
abstract contract LeverageUsingSiloFlashloan is
    ILeverageUsingSiloFlashloan,
    IERC3156FlashBorrower,
    RevenueModule,
    TransientReentrancy,
    LeverageTxState
{
    using SafeERC20 for IERC20;

    IWrappedNativeToken public immutable NATIVE_TOKEN;

    bytes32 internal constant _FLASHLOAN_CALLBACK = keccak256("ERC3156FlashBorrower.onFlashLoan");

    constructor(address _native) {
        require(_native != address(0), EmptyNativeToken());

        NATIVE_TOKEN = IWrappedNativeToken(_native);
    }

    function openLeveragePositionPermit(
        FlashArgs calldata _flashArgs,
        bytes calldata _swapArgs,
        DepositArgs calldata _depositArgs,
        Permit calldata _depositAllowance
    )
        external
        virtual
    {
        _executePermit(_depositAllowance, _depositArgs.silo.asset());

        openLeveragePosition(_flashArgs, _swapArgs, _depositArgs);
    }

    /// @inheritdoc ILeverageUsingSiloFlashloan
    function openLeveragePosition(
        FlashArgs calldata _flashArgs,
        bytes calldata _swapArgs,
        DepositArgs calldata _depositArgs
    )
        public
        payable
        virtual
        nonReentrant
        setupTxState(_depositArgs.silo, LeverageAction.Open, _flashArgs.flashloanTarget)
    {
        // BUG: deposit will transfer tokens to this contract, then SWAP will include this as amountOut
        if (msg.value != 0) {
            require(msg.value == _depositArgs.amount, NativeTokenAmountNotEnough());

            NATIVE_TOKEN.deposit{value: msg.value}();
        }

        require(IERC3156FlashLender(_flashArgs.flashloanTarget).flashLoan({
            _receiver: this,
            _token: ISilo(_flashArgs.flashloanTarget).asset(),
            _amount: _flashArgs.amount,
            _data: abi.encode(_swapArgs, _depositArgs)
        }), FlashloanFailed());
    }

    function closeLeveragePositionPermit(
        FlashArgs calldata _flashArgs,
        bytes calldata _swapArgs,
        CloseLeverageArgs calldata _closeArgs,
        Permit calldata _withdrawAllowance
    )
        external
        virtual
    {
        _executePermit(_withdrawAllowance, address(_closeArgs.siloWithCollateral));

        closeLeveragePosition(_flashArgs, _swapArgs, _closeArgs);
    }

    function closeLeveragePosition(
        FlashArgs calldata _flashArgs,
        bytes calldata _swapArgs,
        CloseLeverageArgs calldata _closeArgs
    )
        public
        virtual
        nonReentrant
        setupTxState(_closeArgs.siloWithCollateral, LeverageAction.Close, _flashArgs.flashloanTarget)
    {
        require(IERC3156FlashLender(_flashArgs.flashloanTarget).flashLoan({
            _receiver: this,
            _token: ISilo(_flashArgs.flashloanTarget).asset(),
            _amount: _flashArgs.amount,
            _data: abi.encode(_swapArgs, _closeArgs)
        }), FlashloanFailed());
    }

    /// @inheritdoc IERC3156FlashBorrower
    function onFlashLoan(
        address _initiator,
        address _borrowToken,
        uint256 _flashloanAmount,
        uint256 _flashloanFee,
        bytes calldata _data
    )
        external
        returns (bytes32)
    {
        // this check prevents call `onFlashLoan` directly
        require(_txFlashloanTarget == msg.sender, InvalidFlashloanLender());
        require(_initiator == address(this), InvalidInitiator());

        if (_txAction == LeverageAction.Open) {
            _openLeverage(_flashloanAmount, _flashloanFee, _data);
        } else if (_txAction == LeverageAction.Close) {
            _closeLeverage(_borrowToken, _flashloanAmount, _flashloanFee, _data);
        } else revert UnknownAction();

        // approval for repay flashloan
        _setMaxAllowance(IERC20(_borrowToken), _txFlashloanTarget, _flashloanAmount + _flashloanFee);

        return _FLASHLOAN_CALLBACK;
    }

    function _openLeverage(
        uint256 _flashloanAmount,
        uint256 _flashloanFee,
        bytes calldata _data
    )
        internal
    {
        DepositArgs memory depositArgs;
        uint256 collateralAmountAfterSwap;

        {
            bytes memory swapArgs;

            (
                swapArgs,
                depositArgs
            ) = abi.decode(_data, (bytes, DepositArgs));

            // swap all flashloan amount into collateral token
            collateralAmountAfterSwap = _fillQuote(swapArgs, _flashloanAmount);
        }

        uint256 totalDeposit = depositArgs.amount + collateralAmountAfterSwap;

        // Fee is taken on totalDeposit = user deposit amount + collateral amount after swap
        uint256 feeForLeverage = _calculateLeverageFee(totalDeposit);
        // we could take cut on user original deposit amount to pay fee, but what's the point of doing leverage then?
        require(collateralAmountAfterSwap > feeForLeverage, LeverageToLowToCoverFee());

        totalDeposit -= feeForLeverage;

        address collateralAsset = depositArgs.silo.asset();

        _deposit({_depositArgs: depositArgs, _totalDeposit: totalDeposit, _asset: collateralAsset});

        {
            ISilo borrowSilo = _resolveOtherSilo(depositArgs.silo);

            // borrow asset wil be used to repay flashloan with fee
            borrowSilo.borrow({
                _assets: _flashloanAmount + _flashloanFee,
                _receiver: address(this),
                _borrower: _txMsgSender
            });
        }

        emit OpenLeverage({
            borrower: _txMsgSender,
            borrowerDeposit: depositArgs.amount,
            swapAmountOut: collateralAmountAfterSwap,
            flashloanAmount: _flashloanAmount,
            totalDeposit: totalDeposit,
            totalBorrow: _flashloanAmount + _flashloanFee,
            leverageFee: feeForLeverage,
            flashloanFee: _flashloanFee
        });

        _payLeverageFee(collateralAsset, feeForLeverage);
    }

    function _deposit(DepositArgs memory _depositArgs, uint256 _totalDeposit, address _asset) internal virtual {
        if (!_txUseNative) {
            // transfer collateral tokens from borrower
            IERC20(_asset).safeTransferFrom(_txMsgSender, address(this), _depositArgs.amount);
        } // else, we expect to have deposited native and got wrapped

        _setMaxAllowance(IERC20(_asset), address(_depositArgs.silo), _totalDeposit);

        _depositArgs.silo.deposit({
            _assets: _totalDeposit,
            _receiver: _txMsgSender,
            _collateralType: _depositArgs.collateralType
        });
    }
    
    function _closeLeverage(
        address _debtToken,
        uint256 _flashloanAmount,
        uint256 _flashloanFee,
        bytes calldata _data
    )
        internal
    {
        (
            bytes memory swapArgs,
            CloseLeverageArgs memory closeArgs
        ) = abi.decode(_data, (bytes, CloseLeverageArgs));

        ISilo siloWithDebt = _resolveOtherSilo(closeArgs.siloWithCollateral);

        _setMaxAllowance({
            _asset: IERC20(_debtToken),
            _spender: address(siloWithDebt),
            _requiredAmount: _flashloanAmount
        });

        siloWithDebt.repayShares(_getBorrowerTotalShareDebtBalance(siloWithDebt), _txMsgSender);

        uint256 sharesToRedeem = _getBorrowerTotalShareCollateralBalance(closeArgs);

        // withdraw all collateral
        uint256 withdrawnDeposit = closeArgs.siloWithCollateral.redeem({
            _shares: sharesToRedeem,
            _receiver: address(this),
            _owner: _txMsgSender,
            _collateralType: closeArgs.collateralType
        });

        // swap collateral to debt to repay flashloan
        uint256 availableDebtAssets = _fillQuote(swapArgs, withdrawnDeposit);

        uint256 obligation = _flashloanAmount + _flashloanFee;
        require(availableDebtAssets >= obligation, SwapDidNotCoverObligations());

        uint256 borrowerDebtChange = availableDebtAssets - obligation;

        emit CloseLeverage({
            borrower: _txMsgSender,
            flashloanRepay: _flashloanAmount,
            swapAmountOut: availableDebtAssets,
            depositWithdrawn: withdrawnDeposit
        });

        if (borrowerDebtChange != 0) IERC20(_debtToken).safeTransfer(_txMsgSender, borrowerDebtChange);

        IERC20 collateralAsset = IERC20(closeArgs.siloWithCollateral.asset());
        uint256 collateralToTransfer = collateralAsset.balanceOf(address(this));
        if (collateralToTransfer != 0) collateralAsset.safeTransfer(_txMsgSender, collateralToTransfer);
    }

    function _fillQuote(bytes memory _swapArgs, uint256 _approval) internal virtual returns (uint256 amountOut);

    function _setMaxAllowance(IERC20 _asset, address _spender, uint256 _requiredAmount) internal virtual {
        uint256 allowance = _asset.allowance(address(this), _spender);
        if (allowance < _requiredAmount) _asset.forceApprove(_spender, type(uint256).max);
    }

    function _getBorrowerTotalShareDebtBalance(ISilo _siloWithDebt)
        internal
        view
        virtual
        returns (uint256 repayShareBalance)
    {
        (,, address shareDebtToken) = _txSiloConfig.getShareTokens(address(_siloWithDebt));
        repayShareBalance = IERC20(shareDebtToken).balanceOf(_txMsgSender);
    }

    function _getBorrowerTotalShareCollateralBalance(CloseLeverageArgs memory closeArgs)
        internal
        view
        virtual
        returns (uint256 balanceOf)
    {
        if (closeArgs.collateralType == ISilo.CollateralType.Collateral) {
            return closeArgs.siloWithCollateral.balanceOf(_txMsgSender);
        }

        (address protectedShareToken,,) = _txSiloConfig.getShareTokens(address(closeArgs.siloWithCollateral));

        balanceOf = ISilo(protectedShareToken).balanceOf(_txMsgSender);
    }

    function _resolveOtherSilo(ISilo _thisSilo) internal view returns (ISilo otherSilo) {
        (address silo0, address silo1) = _txSiloConfig.getSilos();
        require(address(_thisSilo) == silo0 || address(_thisSilo) == silo1, InvalidSilo());

        otherSilo = ISilo(silo0 == address(_thisSilo) ? silo1 : silo0);
    }

    function _executePermit(Permit memory _permit, address _token) internal virtual {
        IERC20Permit(_token).permit({
            owner: _permit.owner,
            spender: _permit.spender,
            value: _permit.value,
            deadline: _permit.deadline,
            v: _permit.v,
            r: _permit.r,
            s: _permit.s
        });
    }
}
