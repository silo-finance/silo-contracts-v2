// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console2} from "forge-std/console2.sol";


import {Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {Math} from "openzeppelin5/utils/math/Math.sol";

import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {ISilo} from "../interfaces/ISilo.sol";
import {ISiloLeverage} from "../interfaces/ISiloLeverage.sol";

import {ZeroExSwapModule} from "./modules/ZeroExSwapModule.sol";
import {RevenueModule} from "./modules/RevenueModule.sol";
import {FlashloanModule} from "./modules/FlashloanModule.sol";
import {LeverageModule} from "./modules/LeverageModule.sol";

// TODO ensure it will that work for Pendle
// TODO is it worth to make swap module external contract and do delegate call? that way we can stay with one SiloLeverage
// and swap module can be picked up by argument
contract SiloLeverage is ISiloLeverage, ZeroExSwapModule, RevenueModule, FlashloanModule, LeverageModule {

    constructor (address _initialOwner) Ownable(_initialOwner) {}

    /// @inheritdoc ISiloLeverage
    function leverage(
        FlashArgs calldata _flashArgs,
        address _swapper,
        SwapArgs calldata _swapArgs,
        DepositArgs calldata _depositArgs
    ) external virtual returns (uint256 totalDeposit, uint256 totalBorrow) {
        _setTransient(_depositArgs.silo, LeverageAction.Open, _flashArgs.flashloanTarget);

        bytes memory data = abi.encode(_swapArgs, _depositArgs);

        _executeFlashloan(_flashArgs, data);

        totalDeposit = __totalDeposit;
        totalBorrow = __totalBorrow;

        _resetTransient();
        // TODO: does is worth to add check for delta balance + fee at the end?
    }

    function closeLeverage(
        FlashArgs calldata _flashArgs,
        SwapArgs calldata _swapArgs,
        CloseLeverageArgs calldata _closeLeverageArgs
    ) external virtual {
        _setTransient(_closeLeverageArgs.siloWithCollateral, LeverageAction.Close, _flashArgs.flashloanTarget);

        bytes memory data = abi.encode(_swapArgs, _closeLeverageArgs);

        _executeFlashloan(_flashArgs, data);

        _resetTransient();
    }

    function _openLeverage(
        address _borrowToken,
        uint256 _flashloanAmount,
        uint256 _flashloanFee,
        bytes calldata _data
    )
        internal
    {
        (
            SwapArgs memory swapArgs,
            ISiloLeverage.DepositArgs memory depositArgs
        ) = abi.decode(_data, (SwapArgs, DepositArgs));

        // swap all flashloan amount into collateral token
        uint256 swapAmountOut = _fillQuote(swapArgs, _flashloanAmount);

        _openLeveragePosition(depositArgs, swapAmountOut, _borrowToken, _flashloanAmount, _flashloanFee);
    }

    function _giveMaxAllowance(IERC20 _asset, address _spender, uint256 _requiredAmount) internal {
        uint256 allowance = _asset.allowance(address(this), _spender);
        if (allowance < _requiredAmount) _asset.forceApprove(_spender, type(uint256).max);
    }

    function _setTransient(ISilo _silo, LeverageAction _action, address _flashloanTarget) internal {
        __flashloanTarget = _flashloanTarget;
        __action = _action;
        __msgSender = msg.sender;
        __siloConfig = _silo.config();
    }
    
    function _resetTransient() internal {
        __totalDeposit = 0;
        __totalBorrow = 0;
        __flashloanTarget = address(0);
        __action = LeverageAction.Undefined;
        __msgSender = address(0);
    }
}
