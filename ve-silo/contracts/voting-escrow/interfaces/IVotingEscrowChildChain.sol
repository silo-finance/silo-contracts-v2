// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IAny2EVMMessageReceiver} from "chainlink-ccip/v0.8/ccip/interfaces/IAny2EVMMessageReceiver.sol";

import {IVeSilo} from "./IVeSilo.sol";

/// @notice Child chain voting escrow interface
interface IVotingEscrowChildChain is IAny2EVMMessageReceiver {
    /// @notice Emit after message was successfully received and processed
    /// @param messageId Message id assigned by Chainlink router
    event MessageReceived(bytes32 indexed messageId);

    /// @notice Emit when main chain sender configured
    event MainChainSenderConfiguered(address sender);

    /// @notice Emit when a user balance updated
    /// @param user with balance was updated
    /// @param lockedEnd End of tokens lock period
    /// @param userPoint User balance
    event UserBalanceUpdated(address indexed user, uint256 lockedEnd, IVeSilo.Point userPoint);

    /// @notice Emit when the total supply was updated
    /// @param totalSupplyPoint Total supply
    event TotalSupplyUpdated(IVeSilo.Point totalSupplyPoint);

    /// @dev Revert if nothing to withdraw
    error NothingToWithdraw();
    /// @dev Revert if received a message from the other then main chain
    error UnsupportedSourceChain();
    /// @dev Revert if the message sender is not an authorized one 
    error UnauthorizedSender();
    /// @dev If the received message has a different message type than `IVeSiloDelegatorViaCCIP.MessageType`
    error UnknownMessageType();
    /// @dev Revert if failed to withdraw
    error FailedToWithdraw(address target, uint256 value);

    /// @notice Withdraw coins if someone sends/bridged them accidentally
    function withdraw(address _beneficiary) external;

    /// @notice Withdraw tokens if someone sends/bridged them accidentally
    function withdrawToken(address _beneficiary, address _token) external;

    /// @notice Provides a possibility to configure a source chain sender
    /// @param _mainChainSender Main chain sender to be authorized to update data
    function setSourceChainSender(address _mainChainSender) external;
    
    /// @param _user User address
    /// @return balance of the `_user` in the child chain
    function balanceOf(address _user) external view returns (uint256 balance);

    /// @return result VeSilo total supply in the child chain
    function totalSupply() external view returns (uint256 result);

    /// @return endOfLockPeriod of the `_user`
    // solhint-disable-next-line func-name-mixedcase
    function locked__end(address _user) external view returns (uint256 endOfLockPeriod);
}
