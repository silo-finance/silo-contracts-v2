// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import {ERC4626} from "openzeppelin5/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {ERC20} from "openzeppelin5/token/ERC20/ERC20.sol";

contract Vault0 is ERC4626 {
   constructor(IERC20 asset) ERC4626(asset) ERC20("Vault0", "VLT0") {}

   function getTotalSupply(address vault) external view returns (uint256) {
      return IERC20(vault).totalSupply();
   }
}
