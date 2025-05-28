// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ILeverageUsingSilo} from "../../interfaces/ILeverageUsingSilo.sol";
import {ISilo} from "../../interfaces/ISilo.sol";
import {ISiloConfig} from "../../interfaces/ISiloConfig.sol";

/// @dev reentrancy contract that stores transient variables for current tx
/// this is done because leverage uses flashloan and because of the flow, we loosing access to eg msg.sender
/// also we can not pass return variables via flashloan
abstract contract LeverageReentrancy {
    /// @dev origin tx msg.sender, acts also as reentrancy flag
    address internal transient __msgSender;

    /// @dev total deposit made for user
    uint256 internal transient __totalDeposit;

    /// @dev total borrower assets
    uint256 internal transient __totalBorrow;

    /// @dev cached silo config
    ISiloConfig internal transient __siloConfig;

    /// @dev information about current action
    ILeverageUsingSilo.LeverageAction internal transient __action;

    /// @dev address of contract from where we getting flashloan
    address internal transient __flashloanTarget;

    modifier nonReentrant(ISilo _silo, ILeverageUsingSilo.LeverageAction _action, address _flashloanTarget) {
        require(__msgSender == address(0), ILeverageUsingSilo.Reentrancy());
        _setTransient(_silo, _action, _flashloanTarget);

        _;

        _resetTransient();
    }

    function _setTransient(ISilo _silo, ILeverageUsingSilo.LeverageAction _action, address _flashloanTarget)
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
        __action = ILeverageUsingSilo.LeverageAction.Undefined;
        __msgSender = address(0);
    }
}
