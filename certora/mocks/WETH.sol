pragma solidity ^0.8.24;

import { SimpleERC20 } from "./SimpleERC20.sol";

contract WETH is SimpleERC20 {

    function deposit() payable external {
        _mint(msg.sender, msg.value);
    }
}