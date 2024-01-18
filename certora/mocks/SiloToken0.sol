// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { ERC20 } from "gitmodules/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract SiloToken0 is ERC20 {
   constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}
}
