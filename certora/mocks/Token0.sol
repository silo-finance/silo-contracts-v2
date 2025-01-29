// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ERC20 } from "gitmodules/openzeppelin-contracts-5/contracts/token/ERC20/ERC20.sol";

contract Token0 is ERC20 {
   constructor() ERC20("n", "s") {}
}
