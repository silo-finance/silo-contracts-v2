// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import {MintableToken} from "silo-core/test/foundry/_common/MintableToken.sol";

contract TestERC20 is MintableToken {
    constructor(string memory name, string memory symbol, uint8 decimals) MintableToken(decimals) {}
}
