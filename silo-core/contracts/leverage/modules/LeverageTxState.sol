// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ILeverageUsingSilo} from "../../interfaces/ILeverageUsingSilo.sol";
import {ISilo} from "../../interfaces/ISilo.sol";
import {ISiloConfig} from "../../interfaces/ISiloConfig.sol";

/// @dev reentrancy contract that stores transient variables for current tx
/// this is done because leverage uses flashloan and because of the flow, we loosing access to eg msg.sender
/// also we can not pass return variables via flashloan
abstract contract LeverageTxState {
    /// @dev origin tx msg.sender, acts also as reentrancy flag
    address internal transient _txMsgSender;

    /// @dev total deposit made for user
    uint256 internal transient _txTotalDeposit;

    /// @dev total borrower assets
    uint256 internal transient _txTotalBorrow;

    /// @dev cached silo config
    ISiloConfig internal transient _txSiloConfig;

    /// @dev information about current action
    ILeverageUsingSilo.LeverageAction internal transient _txAction;

    /// @dev address of contract from where we getting flashloan
    address internal transient _txFlashloanTarget;

    modifier atomicTxFlow(ISilo _silo, ILeverageUsingSilo.LeverageAction _action, address _flashloanTarget) {
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
