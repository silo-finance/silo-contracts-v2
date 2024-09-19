// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";

import {SiloLittleHelper} from "../../../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc LiquidationCallInsolvencyTest
*/
contract LiquidationCallInsolvencyTest is SiloLittleHelper, Test {
    ISiloConfig siloConfig;

    function setUp() public {
        siloConfig = _setUpLocalFixture(SiloConfigsNames.LOCAL_NO_ORACLE_LTV50_SILO);
        token1.setOnDemand(true);
    }

    /*
    forge test -vv --ffi --mt test_self_Insolvency_1
    */
    function test_self_Insolvency_1() public {
        address borrower = makeAddr("borrower");

        _depositCollateral(9999, borrower, TWO_ASSETS);
        _depositForBorrow(6664, address(1));
        _borrow(6664, borrower, TWO_ASSETS);
        _withdraw(1, borrower);

        uint256 t = 1 days;
        while(silo1.isSolvent(borrower)) {
            vm.warp(block.timestamp + t);
        }

        vm.warp(block.timestamp - t);
//
//        while(silo1.isSolvent(borrower)) {
//            vm.warp(block.timestamp + 1);
//        }
//
//        vm.warp(block.timestamp - 1);
        silo1.accrueInterest();

        emit log_named_uint("time", block.timestamp);
        assertTrue(silo1.isSolvent(borrower), "time reversed - user solvent");

        uint256 debtToCover = silo1.maxRepay(borrower) - 1;

        vm.prank(borrower);
        token1.approve(address(partialLiquidation), debtToCover);

        vm.expectRevert(ISilo.Insolvency.selector);
        vm.prank(borrower);
        partialLiquidation.liquidationCall(address(token0), address(token1), borrower, debtToCover, false);
    }
}
