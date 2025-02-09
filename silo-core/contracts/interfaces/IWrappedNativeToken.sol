// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

interface IWrappedNativeToken is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
    function balanceOf(address user) external view returns (uint256);
}
