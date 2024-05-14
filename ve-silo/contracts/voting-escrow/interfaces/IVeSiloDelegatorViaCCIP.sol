// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IVeSilo} from "ve-silo/contracts/voting-escrow/interfaces/IVeSilo.sol";
import {ICCIPMessageSender} from "ve-silo/contracts/utils/CCIPMessageSender.sol";

/// @notice VeSilo delegator via CCIP allows to send voting power to
/// any other chain that the DAO authorizes.
interface IVeSiloDelegatorViaCCIP {
    /// @notice Defined message type for cross-chain transfer
    /// @dev Used for proper data encoding/decoding
    enum MessageType {
        BalanceAndTotalSupply, // When sending user balance and total supply
        TotalSupply // When sending total supply only
    }

    /// @notice Emit when child chain receiver updated
    /// @param dstChainSelector Destination chain selector
    /// @param receiver Receiver in the destination chain
    event ChildChainReceiverUpdated(uint64 dstChainSelector, address receiver);

    /// @notice Emit when user sent its balance
    /// @param dstChainSelector Destination chain selector
    /// @param localUser Local user address
    /// @param remoteUser User address in the destination chain
    /// @param userPoint VeSilo user point
    /// @param totalSupplyPoint VeSilo total supply point
    event SentUserBalance(
        uint64 dstChainSelector,
        address localUser,
        address remoteUser,
        IVeSilo.Point userPoint,
        IVeSilo.Point totalSupplyPoint
    );

    /// @notice Emit when total supply updated
    /// @param dstChainSelector Destination chain selector
    /// @param totalSupplyPoint VeSilo total supply point
    event SentTotalSupply(uint64 dstChainSelector, IVeSilo.Point totalSupplyPoint);

    /// @dev Reverts on a child chain receiver configuration if the chain id is `0`
    error ChainIdCantBeZero();
    /// @dev Reverts on a transfer to the chain for which the chain receiver is not configured
    error ChainIsNotSupported(uint64 dstChainSelector);

    /// @notice Delegates a user veSilo balance
    /// @param _localUser User address in the L1
    /// @param _dstChainSelector Destinatoion chain id
    /// @param _payFeesIn Pay fees in Native/LINK
    function sendUserBalance(
        address _localUser,
        uint64 _dstChainSelector,
        ICCIPMessageSender.PayFeesIn _payFeesIn
    ) external payable;

    /// @notice Update a total supply
    /// @param _dstChainId Destinatoion chain id
    /// @param _payFeesIn Pay fees in Native/LINK
    function sendTotalSupply(uint64 _dstChainId, ICCIPMessageSender.PayFeesIn _payFeesIn) external payable;

    /// @notice Child chain receiver configuration
    /// @dev Supported networks: https://docs.chain.link/ccip/supported-networks
    /// @param _dstChainId CCIP destination chain identifier
    /// @param _receiver Messages receiver in the child chain
    function setChildChainReceiver(uint64 _dstChainId, address _receiver) external;

    /// @notice Estimate a fee for a user balance transfer
    /// @param _localUser User address in the L1
    /// @param _dstChainSelector Destinatoion chain id
    /// @param _payFeesIn Pay fees in Native/LINK
    /// @return fee Fee required to pay to transfer a user balance
    function estimateSendUserBalance(
        address _localUser,
        uint64 _dstChainSelector,
        ICCIPMessageSender.PayFeesIn _payFeesIn
    ) external view returns (uint256 fee);

    /// @notice Estimate a fee for a total supply transfer
    /// @param _dstChainId Destinatoion chain id
    /// @param _payFeesIn Pay fees in Native/LINK
    /// @return fee Fee required to pay to transfer a total supply
    function estimateSendTotalSupply(
        uint64 _dstChainId,
        ICCIPMessageSender.PayFeesIn _payFeesIn
    ) external view returns (uint256 fee);
}
