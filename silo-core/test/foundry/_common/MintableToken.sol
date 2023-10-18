// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";


contract MintableToken is ERC20 {
    constructor() ERC20("a", "b") {}

    function mint(address _owner, uint256 _amount) external virtual {
        _mint(_owner, _amount);
    }
}
