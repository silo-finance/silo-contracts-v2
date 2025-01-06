// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

/// @dev uniswap requires solidity v7. In order not to include whole git module just for one method, this interface was
/// created
interface IERC20BalanceOf {
   function balanceOf(address) external view returns (uint256);
}
