// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {SiloLendingLib} from "silo-core/contracts/lib/SiloLendingLib.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

import {TokenMock} from "silo-core/test/foundry/_mocks/TokenMock.sol";
import "../../data-readers/MaxBorrowValueToAssetsAndSharesTestData.sol";

/*
    forge test -vv --mc MaxBorrowValueToAssetsAndSharesTest
*/
contract MaxBorrowValueToAssetsAndSharesTest is Test {
    TokenMock immutable debtToken;

    MaxBorrowValueToAssetsAndSharesTestData immutable tests;

    constructor() {
        debtToken = new TokenMock(address(0xDDDDDDDDDDDDDD));
        tests = new MaxBorrowValueToAssetsAndSharesTestData(debtToken.ADDRESS());
    }

    /*
    forge test -vv --mt test_maxBorrowValueToAssetsAndShares_loop
    */
    function test_maxBorrowValueToAssetsAndShares_loop() public {
        MaxBorrowValueToAssetsAndSharesTestData.MBVData[] memory testDatas = tests.getData();

        for (uint256 i; i < testDatas.length; i++) {
            vm.clearMockedCalls();
            emit log_string(testDatas[i].name);

            (uint256 maxAssets, uint256 maxShares) = SiloLendingLib.maxBorrowValueToAssetsAndShares(
                testDatas[i].input.maxBorrowValue,
                testDatas[i].input.debtToken,
                ISiloOracle(address(0)),
                testDatas[i].input.totalDebtAssets,
                testDatas[i].input.totalDebtShares
            );

            assertEq(maxAssets, testDatas[i].output.assets, string(abi.encodePacked(testDatas[i].name, " > assets")));
            assertEq(maxShares, testDatas[i].output.shares, string(abi.encodePacked(testDatas[i].name, " > shares")));
        }
    }
}
