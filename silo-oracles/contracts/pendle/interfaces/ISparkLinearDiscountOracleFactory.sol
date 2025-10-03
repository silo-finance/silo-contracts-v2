// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface ISparkLinearDiscountOracleFactory {
    function createWithPt(address ptToken, uint256 baseDiscountPerYear) external returns (address res);
}
