// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import {TestERC20} from "./TestERC20.sol";

contract TestWETH is TestERC20 {
    constructor(string memory name, string memory symbol, uint8 decimals) TestERC20(name, symbol, decimals) {}

    function deposit() external payable {
        _mint(msg.sender, msg.value);
    }
}
