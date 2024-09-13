// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IRouterClient} from "chainlink-ccip/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "chainlink-ccip/v0.8/ccip/interfaces/IAny2EVMMessageReceiver.sol";
import {IERC20} from "openzeppelin5/token/ERC20/ERC20.sol";
import {Address} from "openzeppelin5/utils/Address.sol";

contract CCIPRouterClientLike is IRouterClient {
    uint256 public constant FEE = 0.001e18;

    // solhint-disable var-name-mixedcase
    address public immutable SILO_LIKE_TOKEN;
    address public immutable LINK_LIKE_TOKEN;
    address private immutable _DEPLOYER;
    // solhint-enable var-name-mixedcase

    constructor(address _siloLikeToken, address _linkLikeToken) {
        SILO_LIKE_TOKEN = _siloLikeToken;
        LINK_LIKE_TOKEN = _linkLikeToken;
        _DEPLOYER = msg.sender;
    }

    /// @inheritdoc IRouterClient
    function ccipSend(
        uint64 destinationChainSelector,
        Client.EVM2AnyMessage calldata message
    ) external payable returns (bytes32) {
        if (message.feeToken == LINK_LIKE_TOKEN) {
            uint256 allowance = IERC20(LINK_LIKE_TOKEN).allowance(msg.sender, address(this));

            if (allowance < FEE) revert InsufficientFeeTokenAmount();

            IERC20(LINK_LIKE_TOKEN).transferFrom(msg.sender, address(this), FEE);
        } else {
            if (msg.value != FEE) revert InvalidMsgValue();
            Address.sendValue(payable(_DEPLOYER), msg.value);
        }

        if (message.tokenAmounts.length != 0) {
            IERC20(SILO_LIKE_TOKEN).transferFrom(msg.sender, address(this), message.tokenAmounts[0].amount);
        }

        return keccak256(abi.encode(destinationChainSelector, message));
    }

    /// @inheritdoc IRouterClient
    function isChainSupported(uint64) external pure returns (bool supported) {
        supported = true;
    }

    /// @inheritdoc IRouterClient
    function getSupportedTokens(uint64) external pure returns (address[] memory tokens) {
        tokens = new address[](1);
        tokens[0] = address(0);
    }

    /// @inheritdoc IRouterClient
    function getFee(
        uint64,
        Client.EVM2AnyMessage memory
    ) external pure returns (uint256 fee) {
        fee = FEE;
    }
}
