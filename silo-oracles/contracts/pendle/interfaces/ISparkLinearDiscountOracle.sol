// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface ISparkLinearDiscountOracle {
    function baseDiscountPerYear() external view returns (uint256);
}
