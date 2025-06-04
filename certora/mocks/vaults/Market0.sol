// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import {ERC4626, IERC4626} from "openzeppelin5/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {ERC20} from "openzeppelin5/token/ERC20/ERC20.sol";

contract Market0 is ERC4626 {
   constructor(IERC20 asset) ERC4626(asset) ERC20("Market0", "MRK0") {}

   function getTotalSupply(address vault) external view returns (uint256) {
      return IERC20(vault).totalSupply();
   }

   function getConvertToShares(address vault, uint256 assets) external view returns (uint256) {
        return IERC4626(vault).convertToShares(assets);
   }

   function getConvertToAssets(address vault, uint256 shares) external view returns (uint256) {
        return IERC4626(vault).convertToAssets(shares);
   }
}
