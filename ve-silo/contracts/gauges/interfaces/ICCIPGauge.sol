// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Client} from "chainlink-ccip/v0.8/ccip/libraries/Client.sol";

import {IStakelessGauge} from "./IStakelessGauge.sol";
import {ICCIPExtraArgsConfig} from "./ICCIPExtraArgsConfig.sol";

interface ICCIPGauge is IStakelessGauge, ICCIPExtraArgsConfig {
    enum PayFeesIn {
        Native,
        LINK
    }

    /// @notice Construct a CCIP message.
    /// @dev This function will create an EVM2AnyMessage struct with all the necessary information for tokens transfer.
    /// @param _amount The amount of the token to be transferred.
    /// @return evm2AnyMessage Returns an EVM2AnyMessage struct which contains information for sending a CCIP message.
    function buildCCIPMessage(
        uint256 _amount,
        PayFeesIn _payFeesIn
    )
        external
        view
        returns (Client.EVM2AnyMessage memory evm2AnyMessage);
    
    /// @notice Calculates the fee required to send the message
    /// @param _amount The amount of the token to be transferred.
    /// @param _payFeesIn Pay fees in LINK or Native
    /// @return fee to send a `_message`
    function calculateFee(uint256 _amount, PayFeesIn _payFeesIn) external view returns (uint256 fee);
}
