// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IERC20Handler {
    function approve(uint256 amount, uint8 i, uint8 j) external;
    function transfer(uint256 amount, uint8 i, uint8 j) external;
    function transferFrom(uint256 amount, uint8 i, uint8 j, uint8 k) external;
}
