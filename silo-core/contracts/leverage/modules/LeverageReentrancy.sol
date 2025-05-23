// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {ISiloLeverageZeroEx} from "../../interfaces/ISiloLeverageZeroEx.sol";

contract LeverageReentrancy {
    address internal  __msgSender;
    uint256 internal  __totalDeposit;
    uint256 internal  __totalBorrow;
    ISiloConfig  __siloConfig;
    ISiloLeverageZeroEx.LeverageAction  __action;
    address  __flashloanTarget;

    modifier nonReentrant() { // TODO params?
        require(__msgSender == address(0), ISiloLeverageZeroEx.Reentrancy());

        _;

        _resetTransient();
    }

    function _setTransient(ISilo _silo, ISiloLeverageZeroEx.LeverageAction _action, address _flashloanTarget) internal {
        __flashloanTarget = _flashloanTarget;
        __action = _action;
        __msgSender = msg.sender;
        __siloConfig = _silo.config();
    }

    function _resetTransient() internal {
        __totalDeposit = 0;
        __totalBorrow = 0;
        __flashloanTarget = address(0);
        __action = ISiloLeverageZeroEx.LeverageAction.Undefined;
        __msgSender = address(0);
    }
}
