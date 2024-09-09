// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IRouterClient} from "chainlink-ccip/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "chainlink-ccip/v0.8/ccip/libraries/Client.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {Address} from "openzeppelin5/utils/Address.sol";

import {ICCIPGauge, IStakelessGauge} from "ve-silo/contracts/gauges/interfaces/ICCIPGauge.sol";
import {StakelessGauge, Ownable2Step, IMainnetBalancerMinter} from "../stakeless-gauge/StakelessGauge.sol";

abstract contract CCIPGauge is StakelessGauge, ICCIPGauge {
    // solhint-disable var-name-mixedcase
    IRouterClient public immutable ROUTER;
    address public immutable LINK;
    // solhint-enable var-name-mixedcase

    uint64 public destinationChain;
    bytes public extraArgs;

    address internal _chaildChainGauge;

    event CCIPTransferMessage(bytes32 messageId);

    constructor(
        IMainnetBalancerMinter _minter,
        address _router,
        address _link
    ) StakelessGauge(_minter) {
        ROUTER = IRouterClient(_router);
        LINK = _link;
    }

    function initialize(
        address _recepient,
        uint256 _relativeWeightCap,
        address _checkpointer,
        uint64 _destinationChain
    )
        external
    {
        // This will revert in all calls except the first one
        __StakelessGauge_init(_relativeWeightCap);

        _setCheckpointer(_checkpointer);

        // Transfer ownership to the Factory's owner (DAO)
        _transferOwnership(Ownable2Step(msg.sender).owner());

        _chaildChainGauge = _recepient;
        destinationChain = _destinationChain;
    }

    function setExtraArgs(bytes calldata _extraArgs) external onlyOwner {
        extraArgs = _extraArgs;

        emit ExtraArgsUpdated(_extraArgs);
    }

    /// @inheritdoc ICCIPGauge
    function calculateFee(uint256 _amount, PayFeesIn _payFeesIn) external view returns (uint256 fee) {
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(_amount, _payFeesIn);
        fee = _calculateFee(evm2AnyMessage);
    }

    /// @inheritdoc ICCIPGauge
    function buildCCIPMessage(
        uint256 _amount,
        PayFeesIn _payFeesIn
    )
        external
        view
        returns (Client.EVM2AnyMessage memory evm2AnyMessage)
    {
        evm2AnyMessage = _buildCCIPMessage(_amount, _payFeesIn);
    }
    
    /// @inheritdoc IStakelessGauge
    function getRecipient() external view returns (address) {
        return _chaildChainGauge;
    }

    function _postMintAction(uint256 _mintAmount) internal override {
        _balToken.approve(address(ROUTER), _mintAmount);

        bytes32 messageId;
        uint256 balance = address(this).balance;

        if (balance != 0) {
            Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(_mintAmount, PayFeesIn.Native);
            // Get the fee required to send the message
            uint256 fees = _calculateFee(evm2AnyMessage);

            if (balance >= fees) { // Ensure that we have enough ether to pay fees
                messageId = ROUTER.ccipSend{ value: fees }(
                    destinationChain,
                    evm2AnyMessage
                );
            } else { // If we don't have enough ether to pay fees, try to pay with LINK
                messageId = _transferMessageAndPayInLINK(_mintAmount);
            }

            _returnLeftoverIfAny();
        } else {
            messageId = _transferMessageAndPayInLINK(_mintAmount);
        }

        emit CCIPTransferMessage(messageId);
    }

    function _transferMessageAndPayInLINK(uint256 _mintAmount) internal returns (bytes32 messageId) {
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(_mintAmount, PayFeesIn.LINK);
        // Get the fee required to send the message
        uint256 fees = _calculateFee(evm2AnyMessage);

        // Expect tokens to be already transferred to the gauge balance by the `CCIPGaugeCheckpointer`
        IERC20(LINK).approve(address(ROUTER), fees);

        messageId = ROUTER.ccipSend(
            destinationChain,
            evm2AnyMessage
        );
    }

    /// @dev Ensure that the contract returns any leftover ether or LINK to the sender
    function _returnLeftoverIfAny() internal {
        uint256 remainingBalance = address(this).balance;

        if (remainingBalance > 0) {
            Address.sendValue(payable(msg.sender), remainingBalance);
        }

        uint256 remainingLINKBalance = IERC20(LINK).balanceOf(address(this));

        if (remainingLINKBalance > 0) {
            IERC20(LINK).transfer(msg.sender, remainingLINKBalance);
        }
    }

    function _calculateFee(Client.EVM2AnyMessage memory _message) internal view returns (uint256 fee) {
        fee = ROUTER.getFee(
            destinationChain,
            _message
        );
    }

    function _buildCCIPMessage(
        uint256 _amount,
        PayFeesIn _payFeesIn
    )
        internal
        view
        returns (Client.EVM2AnyMessage memory evm2AnyMessage)
    {
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);

        Client.EVMTokenAmount memory tokenAmount = Client.EVMTokenAmount({
            token: address(_balToken),
            amount: _amount
        });

        tokenAmounts[0] = tokenAmount;

        evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(_chaildChainGauge),
            data: "",
            tokenAmounts: tokenAmounts,
            extraArgs: extraArgs,
            feeToken: _payFeesIn == PayFeesIn.Native ? address(0) : LINK
        });
    }
}
