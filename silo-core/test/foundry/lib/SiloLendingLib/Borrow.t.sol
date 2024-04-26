//// SPDX-License-Identifier: BUSL-1.1
//pragma solidity ^0.8.0;
//
// TODO
//import "forge-std/Test.sol";
//
//import {SiloLendingLib} from "silo-core/contracts/lib/SiloLendingLib.sol";
//import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
//import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
//
//import {TokenMock} from "silo-core/test/foundry/_mocks/TokenMock.sol";
//import {SiloLendingLibBorrowTestData} from "../../data-readers/SiloLendingLibBorrowTestData.sol";
//import {SiloLendingLibImpl} from "../../_common/SiloLendingLibImpl.sol";
//
///*
//    forge test -vv --mc BorrowTest
//*/
//contract BorrowTest is Test {
//    ISilo.Assets totalDebt;
//
//    TokenMock immutable protectedShareToken;
//    TokenMock immutable collateralShareToken;
//    TokenMock immutable debtShareToken;
//    TokenMock immutable debtToken;
//
//    SiloLendingLibBorrowTestData immutable tests;
//
//    constructor() {
//        protectedShareToken = new TokenMock(address(0x66666666666666666));
//        collateralShareToken = new TokenMock(address(0x7777777777777777));
//        debtShareToken = new TokenMock(address(0x9999999999999));
//        debtToken = new TokenMock(address(0x101010101010101010));
//
//        tests = new SiloLendingLibBorrowTestData(
//            protectedShareToken.ADDRESS(),
//            collateralShareToken.ADDRESS(),
//            debtShareToken.ADDRESS(),
//            debtToken.ADDRESS()
//        );
//    }
//
//    function setUp() public {
//        totalDebt.assets = 0;
//    }
//
//    /*
//    forge test -vv --mt test_borrow_zeros
//    */
//    function test_borrow_zeros() public {
//        ISiloConfig.ConfigData memory configData;
//        uint256 assets;
//        uint256 shares;
//        address receiver;
//        address borrower;
//        address spender;
//        uint256 totalCollateralAssets;
//
//        vm.expectRevert(ISilo.ZeroAssets.selector);
//
//        SiloLendingLib.borrow(
//            configData.debtShareToken,
//            configData.token,
//            spender,
//            ISilo.BorrowArgs({
//                assets: assets,
//                shares: shares,
//                receiver: receiver,
//                borrower: borrower,
//                sameAsset: false,
//                leverage: false,
//                totalCollateralAssets: totalCollateralAssets
//            }),
//            totalDebt
//        );
//    }
//
//    /*
//    forge test -vv --mt test_borrow_loop
//    */
//    function test_borrow_loop() public {
//        SiloLendingLibBorrowTestData.SLLBData[] memory testDatas = tests.getData();
//        SiloLendingLibImpl impl = new SiloLendingLibImpl();
//
//        for (uint256 i; i < testDatas.length; i++) {
//            vm.clearMockedCalls();
//            emit log_string(testDatas[i].name);
//            bool txReverts = testDatas[i].output.reverts != bytes4(0);
//
//            totalDebt.assets = testDatas[i].input.initTotalDebt;
//
//            if (testDatas[i].mocks.debtSharesTotalSupplyMock) {
//                debtShareToken.totalSupplyMock(testDatas[i].mocks.debtSharesTotalSupply, !txReverts);
//            }
//
//            if (testDatas[i].output.borrowedShare != 0) {
//                debtToken.transferMock(
//                    testDatas[i].input.receiver,
//                    testDatas[i].output.borrowedAssets
//                );
//
//                debtShareToken.mintMock(testDatas[i].input.borrower, testDatas[i].input.spender, testDatas[i].output.borrowedShare);
//            }
//
//            if (txReverts) {
//                vm.expectRevert(testDatas[i].output.reverts);
//            }
//
//            (uint256 borrowedAssets, uint256 borrowedShares) = impl.borrow(
//                testDatas[i].input.configData.debtShareToken,
//                testDatas[i].input.configData.token,
//                testDatas[i].input.assets,
//                testDatas[i].input.shares,
//                testDatas[i].input.receiver,
//                testDatas[i].input.borrower,
//                testDatas[i].input.spender,
//                totalDebt,
//                testDatas[i].input.totalCollateralAssets
//            );
//
//            assertEq(borrowedAssets, testDatas[i].output.borrowedAssets, string(abi.encodePacked(testDatas[i].name, " > borrowedAssets")));
//            assertEq(borrowedShares, testDatas[i].output.borrowedShare, string(abi.encodePacked(testDatas[i].name, " > borrowedShare")));
//        }
//    }
//}
