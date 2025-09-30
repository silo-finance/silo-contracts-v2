// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {Test} from "forge-std/Test.sol";

import {ISparkLinearDiscountOracleFactory} from
    "silo-oracles/contracts/pendle/interfaces/ISparkLinearDiscountOracleFactory.sol";

contract SparkLinearDiscountOracleFactoryMock is ISparkLinearDiscountOracleFactory, Test {
    function createWithPt(address, /* pt */ uint256 /* baseDiscountPerYear */ ) external returns (address res) {
        res = makeAddr("sparkLinearDiscountOracle");
    }
}
