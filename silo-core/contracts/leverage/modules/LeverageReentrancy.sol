// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ILeverageUsingSilo} from "../../interfaces/ILeverageUsingSilo.sol";
import {ISilo} from "../../interfaces/ISilo.sol";
import {ISiloConfig} from "../../interfaces/ISiloConfig.sol";

contract LeverageReentrancy {
    address internal transient _txMsgSender;
    uint256 internal transient _txTotalDeposit;
    uint256 internal transient _txTotalBorrow;
    ISiloConfig internal transient _txSiloConfig;
    ILeverageUsingSilo.LeverageAction internal transient _txAction;
    address internal transient _txFlashloanTarget;

    modifier nonReentrant(ISilo _silo, ILeverageUsingSilo.LeverageAction _action, address _flashloanTarget) {
        require(_txMsgSender == address(0), ILeverageUsingSilo.Reentrancy());
        _setTransient(_silo, _action, _flashloanTarget);

        _;

        _resetTransient();
    }

    function _setTransient(ISilo _silo, ILeverageUsingSilo.LeverageAction _action, address _flashloanTarget)
        private
    {
        _txFlashloanTarget = _flashloanTarget;
        _txAction = _action;
        _txMsgSender = msg.sender;
        _txSiloConfig = _silo.config();
    }

    function _resetTransient() private {
        _txTotalDeposit = 0;
        _txTotalBorrow = 0;
        _txFlashloanTarget = address(0);
        _txAction = ILeverageUsingSilo.LeverageAction.Undefined;
        _txMsgSender = address(0);
    }
}
