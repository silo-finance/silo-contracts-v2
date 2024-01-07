// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.8.21;

// contracts
import { ERC20 } from "gitmodules/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract Token0 is ERC20 {
   constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}
}