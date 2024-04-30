// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract ContractThatAcceptsETH {
    function anyFunction() external payable {}

    receive() external payable {}
}
