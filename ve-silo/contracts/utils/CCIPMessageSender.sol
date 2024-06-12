// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {IRouterClient} from "chainlink-ccip/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "chainlink-ccip/v0.8/ccip/libraries/Client.sol";

import {ICCIPExtraArgsConfig} from "ve-silo/contracts/gauges/interfaces/ICCIPExtraArgsConfig.sol";

interface ICCIPMessageSender is ICCIPExtraArgsConfig {
    /// @notice Define a fee payment method
    enum PayFeesIn {
        Native, // native chain currency (Ethereum - ether)
        LINK // LINK token
    }

    /// @notice Emit after a message sent via CCIP
    /// @return messageId CCIP message id
    event MessageSentVaiCCIP(bytes32 messageId);
}

/// @notice Send any message via CCIP
/// @dev https://docs.chain.link/ccip
abstract contract CCIPMessageSender is ICCIPMessageSender {
    // solhint-disable var-name-mixedcase
    address public immutable ROUTER;
    address public immutable LINK;
    // solhint-enable var-name-mixedcase

    bytes public extraArgs;

    /// @param _router CCIP router
    /// @param _link LINK token
    constructor(address _router, address _link) {
        ROUTER = _router;
        LINK = _link;
    }

    /// @notice Create a message for CCIP protocol
    /// @param _receiver Message receiver in the destination chain
    /// @param _data Data to be sent
    /// @param _payFeesIn Pay fees in Native/LINK
    function getCCIPMessage(
        address _receiver,
        bytes memory _data,
        PayFeesIn _payFeesIn
    ) public view returns (Client.EVM2AnyMessage memory ccipMessage) {
        ccipMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(_receiver),
            data: abi.encode(_data),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: extraArgs,
            feeToken: _payFeesIn == PayFeesIn.LINK ? LINK : address(0)
        });
    }

    /// @notice Send message via CCIP
    /// @dev Supported networks: https://docs.chain.link/ccip/supported-networks
    /// @param _dstChainSelector CCIP destination chain selector
    /// @param _receiver Message receiver in the destination chain
    /// @param _data Data to be sent
    /// @param _payFeesIn Pay fees in Native/LINK
    /// @return messageId CCIP message id
    function _sendMesssageViaCCIP(
        uint64 _dstChainSelector,
        address _receiver,
        bytes memory _data,
        PayFeesIn _payFeesIn
    )
        internal
        returns (bytes32 messageId)
    {
        Client.EVM2AnyMessage memory ccipMessage = getCCIPMessage(_receiver, _data, _payFeesIn);

        uint256 fee = _calculateFee(_dstChainSelector, ccipMessage);

        if (_payFeesIn == PayFeesIn.LINK) {
            IERC20(LINK).transferFrom(msg.sender, address(this), fee);
            IERC20(LINK).approve(ROUTER, fee);

            messageId = IRouterClient(ROUTER).ccipSend(
                _dstChainSelector,
                ccipMessage
            );
        } else {
            messageId = IRouterClient(ROUTER).ccipSend{value: fee}(
                _dstChainSelector,
                ccipMessage
            );
        }

        emit MessageSentVaiCCIP(messageId);
    }

    /// @notice Calculate fee for a message
    /// @param _dstChainSelector CCIP destination chain selector
    /// @param _ccipMessage Message to be sent
    /// @return fee required to send a `_ccipMessage`
    function _calculateFee(
        uint64 _dstChainSelector,
        Client.EVM2AnyMessage memory _ccipMessage
    ) internal view returns (uint256 fee) {
        fee = IRouterClient(ROUTER).getFee(
            _dstChainSelector,
            _ccipMessage
        );
    }
}
