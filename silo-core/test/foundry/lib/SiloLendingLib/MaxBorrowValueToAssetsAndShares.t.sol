// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

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
    TokenMock immutable debtShareToken;

    MaxBorrowValueToAssetsAndSharesTestData immutable tests;

    constructor() {
        debtToken = new TokenMock(address(0xDDDDDDDDDDDDDD));
        debtShareToken = new TokenMock(address(0xFFFFFFFFFF));
        tests = new MaxBorrowValueToAssetsAndSharesTestData(debtToken.ADDRESS(), debtShareToken.ADDRESS());
    }

    /*
    forge test -vv --mt test_maxBorrowValueToAssetsAndShares_loop
    */
    function test_maxBorrowValueToAssetsAndShares_loop() public {
        MaxBorrowValueToAssetsAndSharesTestData.MBVData[] memory testDatas = tests.getData();

        for (uint256 i; i < testDatas.length; i++) {
            vm.clearMockedCalls();
            emit log_string(testDatas[i].name);

            if (testDatas[i].input.borrowerDebtValue == 0) {
                if (testDatas[i].input.maxBorrowValue != 0) {
                    debtToken.decimalsMock(testDatas[i].mocks.debtTokenDecimals);
                }
            } else {
                debtShareToken.balanceOfMock(testDatas[i].input.borrower, testDatas[i].mocks.debtShareTokenBalanceOf);
            }

            (uint256 maxAssets, uint256 maxShares) = SiloLendingLib.maxBorrowValueToAssetsAndShares(
                testDatas[i].input.maxBorrowValue,
                testDatas[i].input.borrowerDebtValue,
                testDatas[i].input.borrower,
                testDatas[i].input.debtToken,
                testDatas[i].input.debtShareToken,
                ISiloOracle(address(0)),
                testDatas[i].input.totalDebtAssets,
                testDatas[i].input.totalDebtShares
            );

            assertEq(maxAssets, testDatas[i].output.assets, string(abi.encodePacked(testDatas[i].name, " > assets")));
            assertEq(maxShares, testDatas[i].output.shares, string(abi.encodePacked(testDatas[i].name, " > shares")));
        }
    }
}
