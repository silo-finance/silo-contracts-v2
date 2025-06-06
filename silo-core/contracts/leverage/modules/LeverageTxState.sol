// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ILeverageUsingSiloFlashloan} from "../../interfaces/ILeverageUsingSiloFlashloan.sol";
import {ISilo} from "../../interfaces/ISilo.sol";
import {ISiloConfig} from "../../interfaces/ISiloConfig.sol";

/// @dev reentrancy contract that stores  variables for current tx
/// this is done because leverage uses flashloan and because of the flow, we loosing access to eg msg.sender
/// also we can not pass return variables via flashloan
abstract contract LeverageTxState {
    /// @dev origin tx msg.sender, acts also as reentrancy flag
    address internal transient _txMsgSender;

    /// @dev cached silo config
    ISiloConfig internal transient _txSiloConfig;

    /// @dev information about current action
    ILeverageUsingSiloFlashloan.LeverageAction internal transient _txAction;

    /// @dev address of contract from where we getting flashloan
    address internal transient _txFlashloanTarget;

    /// @dev it will inform that we dealing with native token
    uint256 internal transient _txMsgValue;

    modifier setupTxState(ISilo _silo, ILeverageUsingSiloFlashloan.LeverageAction _action, address _flashloanTarget) {
        _txFlashloanTarget = _flashloanTarget;
        _txAction = _action;
        _txMsgSender = msg.sender;
        _txSiloConfig = _silo.config();

        _;
    }
}
