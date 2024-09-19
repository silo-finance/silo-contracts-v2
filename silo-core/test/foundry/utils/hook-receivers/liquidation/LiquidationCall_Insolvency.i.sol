// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IPartialLiquidation} from "silo-core/contracts/interfaces/IPartialLiquidation.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IInterestRateModel} from "silo-core/contracts/interfaces/IInterestRateModel.sol";
import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";
import {AssetTypes} from "silo-core/contracts/lib/AssetTypes.sol";

import {SiloLittleHelper} from "../../../_common/SiloLittleHelper.sol";
import {MintableToken} from "../../../_common/MintableToken.sol";


/*
    forge test -vv --ffi --mc LiquidationCallInsolvencyTest
*/
contract LiquidationCallInsolvencyTest is SiloLittleHelper, Test {
    ISiloConfig siloConfig;

    function setUp() public {
        siloConfig = _setUpLocalFixture();
        token1.setOnDemand(true);
    }

    /*
    forge test -vv --ffi --mt test_self_Insolvency_1
    */
    function test_self_Insolvency_1() public {
        address borrower = makeAddr("borrower");

        _depositCollateral(1e18, borrower, TWO_ASSETS);
        _depositForBorrow(0.75e18, address(1));
        _borrow(0.75e18, borrower, TWO_ASSETS);
        _withdraw(0.10e18, borrower);

        while(silo1.isSolvent(borrower)) {
            vm.warp(block.timestamp + 10 seconds);
        }

        vm.warp(block.timestamp - 10 seconds);

        while(silo1.isSolvent(borrower)) {
            vm.warp(block.timestamp + 1);
        }

        vm.warp(block.timestamp - 1);
        silo1.accrueInterest();

        assertTrue(silo1.isSolvent(borrower), "time reversed - user solvent");

        uint256 debtToCover = silo1.maxRepay(borrower) - 1;

        vm.prank(borrower);
        token1.approve(address(partialLiquidation), debtToCover);

        vm.expectRevert(ISilo.Insolvency.selector);
        vm.prank(borrower);
        partialLiquidation.liquidationCall(address(token0), address(token1), borrower, debtToCover, false);
    }
}
