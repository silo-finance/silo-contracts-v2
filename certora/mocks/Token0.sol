// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { ERC20 } from "gitmodules/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract Token0 is ERC20 {
   constructor() ERC20("n", "s") {}
}
