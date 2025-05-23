// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {ISilo} from "../interfaces/ISilo.sol";
import {ISiloLeverage} from "../interfaces/ISiloLeverage.sol";

import {ZeroExSwapModule} from "./modules/ZeroExSwapModule.sol";
import {RevenueModule} from "./modules/RevenueModule.sol";
import {FlashloanModule} from "./modules/FlashloanModule.sol";
import {LeverageModule} from "./modules/LeverageModule.sol";

// TODO events on state changes
// TODO ensure it will that work for Pendle
// TODO is it worth to make swap module external contract and do delegate call? that way we can stay with one SiloLeverage
// and swap module can be picked up by argument
contract SiloLeverage is ISiloLeverage, ZeroExSwapModule, RevenueModule, FlashloanModule, LeverageModule {
    constructor (address _initialOwner) Ownable(_initialOwner) {}

    /// @inheritdoc ISiloLeverage
    function openLeveragePosition(
        FlashArgs calldata _flashArgs,
        SwapArgs calldata _swapArgs,
        DepositArgs calldata _depositArgs
    ) external virtual returns (uint256 totalDeposit, uint256 totalBorrow) {
        _setTransient(_depositArgs.silo, LeverageAction.Open, _flashArgs.flashloanTarget);

        bytes memory data = abi.encode(_swapArgs, _depositArgs);

        _executeFlashloan(_flashArgs, data);

        totalDeposit = __totalDeposit;
        totalBorrow = __totalBorrow;

        // TODO: does is worth to add check for delta balance + fee at the end?
    }

    function closeLeveragePosition(
        FlashArgs calldata _flashArgs,
        SwapArgs calldata _swapArgs,
        CloseLeverageArgs calldata _closeLeverageArgs
    ) external virtual {
        _setTransient(_closeLeverageArgs.siloWithCollateral, LeverageAction.Close, _flashArgs.flashloanTarget);

        bytes memory data = abi.encode(_swapArgs, _closeLeverageArgs);

        _executeFlashloan(_flashArgs, data);
    }

    function _openLeverage(
        address _borrowToken,
        uint256 _flashloanAmount,
        uint256 _flashloanFee,
        bytes calldata _data
    )
        internal
        override
    {
        (
            SwapArgs memory swapArgs,
            DepositArgs memory depositArgs
        ) = abi.decode(_data, (SwapArgs, DepositArgs));

        // swap all flashloan amount into collateral token
        uint256 amountOut = _fillQuote(swapArgs, _flashloanAmount);

        (__totalDeposit, __totalBorrow) = _openLeverageFlow({
            _depositArgs: depositArgs,
            _depositAsset: IERC20(swapArgs.buyToken),
            _swapAmountOut: amountOut,
            _borrowToken: _borrowToken,
            _flashloanAmount: _flashloanAmount,
            _flashloanFee: _flashloanFee
        });
    }

    function _closeLeverage(
        address _debtToken,
        uint256 _flashloanAmount,
        uint256 _flashloanFee,
        bytes calldata _data
    )
        internal
        override
    {
        (
            SwapArgs memory swapArgs,
            CloseLeverageArgs memory closeArgs
        ) = abi.decode(_data, (SwapArgs, CloseLeverageArgs));

        uint256 depositWithdrawn = _repayDebtAndRedeemCollateral({
            _closeArgs: closeArgs,
            _debtToken: IERC20(_debtToken),
            _flashloanAmount: _flashloanAmount
        });

        // swap debt to collateral
        uint256 amountOut = _fillQuote(swapArgs, _flashloanAmount);

        _sendProfitInDebtTokenToBorrower({
            _availableDebtBalance: amountOut,
            _debtToken: IERC20(_debtToken),
            _flashloanAmount: _flashloanAmount,
            _flashloanFee: _flashloanFee,
            _depositWithdrawn: depositWithdrawn
        });
    }

    function _setTransient(ISilo _silo, LeverageAction _action, address _flashloanTarget) internal {
        __flashloanTarget = _flashloanTarget;
        __action = _action;
        __msgSender = msg.sender;
        __siloConfig = _silo.config();
    }

    function _calculateLeverageFee(uint256 _amount)
        internal
        view
        virtual
        override(LeverageModule, RevenueModule)
        returns (uint256 leverageFeeAmount)
    {
        leverageFeeAmount = RevenueModule._calculateLeverageFee(_amount);
    }

    function _payLeverageFee(address _borrowToken, uint256 _leverageFee)
        internal
        virtual
        override(LeverageModule, RevenueModule)
    {
        RevenueModule._payLeverageFee(_borrowToken, _leverageFee);
    }

    function _setMaxAllowance(IERC20 _asset, address _spender, uint256 _requiredAmount)
        internal
        virtual
        override(FlashloanModule, LeverageModule)
    {
        LeverageModule._setMaxAllowance(_asset, _spender, _requiredAmount);
    }

}
