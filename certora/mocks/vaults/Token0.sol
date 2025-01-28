// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import {ERC20} from "openzeppelin5/token/ERC20/ERC20.sol";

contract Token0 is ERC20 {
   constructor() ERC20("Token0", "TOK0") {}
}
