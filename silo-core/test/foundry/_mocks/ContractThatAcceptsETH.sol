// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

contract ContractThatAcceptsETH {
    function anyFunction() external payable {}

    function anyFunctionThatSendEthBack() external payable {
        payable(msg.sender).transfer(msg.value);
    }

    receive() external payable {}
}
