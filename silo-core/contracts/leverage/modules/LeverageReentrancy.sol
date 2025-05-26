// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ILeverageUsingSiloWithZeroEx} from "../../interfaces/ILeverageUsingSiloWithZeroEx.sol";
import {ISilo} from "../../interfaces/ISilo.sol";
import {ISiloConfig} from "../../interfaces/ISiloConfig.sol";

contract LeverageReentrancy {
    address internal transient __msgSender;
    uint256 internal transient __totalDeposit;
    uint256 internal transient __totalBorrow;
    ISiloConfig internal transient __siloConfig;
    ILeverageUsingSiloWithZeroEx.LeverageAction internal transient __action;
    address internal transient __flashloanTarget;

    modifier nonReentrant(ISilo _silo, ILeverageUsingSiloWithZeroEx.LeverageAction _action, address _flashloanTarget) {
        require(__msgSender == address(0), ILeverageUsingSiloWithZeroEx.Reentrancy());
        _setTransient(_silo, _action, _flashloanTarget);

        _;

        _resetTransient();
    }

    function _setTransient(ISilo _silo, ILeverageUsingSiloWithZeroEx.LeverageAction _action, address _flashloanTarget)
        private
    {
        __flashloanTarget = _flashloanTarget;
        __action = _action;
        __msgSender = msg.sender;
        __siloConfig = _silo.config();
    }

    function _resetTransient() private {
        __totalDeposit = 0;
        __totalBorrow = 0;
        __flashloanTarget = address(0);
        __action = ILeverageUsingSiloWithZeroEx.LeverageAction.Undefined;
        __msgSender = address(0);
    }
}
