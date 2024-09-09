// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract ContractThatAcceptsETH {
    function anyFunction() external payable {}

    function anyFunctionThatSendEthBack() external payable {
        payable(msg.sender).transfer(msg.value);
    }

    receive() external payable {}
}
