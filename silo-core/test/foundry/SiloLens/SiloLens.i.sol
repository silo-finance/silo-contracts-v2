// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {IERC20Errors} from "openzeppelin5/interfaces/draft-IERC6093.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";
import {ShareTokenDecimalsPowLib} from "../_common/ShareTokenDecimalsPowLib.sol";

import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";

/*
    FOUNDRY_PROFILE=core-test forge test -vv --ffi --mc SiloLensTest
*/
contract SiloLensTest is SiloLittleHelper, Test {
    using SiloLensLib for ISilo;
    using ShareTokenDecimalsPowLib for uint256;

    ISiloConfig siloConfig;

    function setUp() public {
        siloConfig = _setUpLocalFixture();

        assertTrue(siloConfig.getConfig(address(silo0)).maxLtv != 0, "we need borrow to be allowed");
    }

    /*
    FOUNDRY_PROFILE=core-test forge test --ffi --mt test_siloLens -vv
    */
    function test_siloLens() public {
        address depositor = makeAddr("depositor");
        address borrower = makeAddr("borrower");

        uint256 deposit0 = 33e18;
        uint256 deposit1 = 11e18;
        uint256 collateral = 11e18;

        _deposit(deposit0, depositor);
        assertTrue(siloLens.hasPosition(siloConfig, depositor), "hasPosition");
        assertTrue(siloLens.hasPosition(siloConfig, depositor), "depositor has position in silo0 but we checking whole market");

        _depositForBorrow(deposit1, depositor);

        assertTrue(siloLens.isSolvent(silo0, depositor), "depositor has no debt");
        assertEq(siloLens.liquidity(silo0), deposit0, "liquidity in silo0");
        assertEq(siloLens.liquidity(silo1), deposit1, "liquidity in silo1");
        assertEq(siloLens.getRawLiquidity(silo0), deposit0, "getRawLiquidity 0");
        assertEq(siloLens.getRawLiquidity(silo1), deposit1, "getRawLiquidity 1");

        _depositCollateral(collateral, borrower, TWO_ASSETS);

        assertFalse(siloLens.inDebt(siloConfig, borrower), "borrower has no debt");

        assertEq(siloLens.liquidity(silo0), deposit0 + collateral, "liquidity in silo0 before borrow");
        assertEq(siloLens.liquidity(silo1), deposit1, "liquidity in silo1 before borrow");
        assertEq(siloLens.getRawLiquidity(silo0), deposit0 + collateral, "getRawLiquidity 0 before borrow");
        assertEq(siloLens.getRawLiquidity(silo1), deposit1, "getRawLiquidity 1 before borrow");

        uint256 toBorrow = silo1.maxBorrow(borrower);
        _borrow(toBorrow, borrower);

        assertTrue(siloLens.isSolvent(silo1, borrower), "borrower is solvent @0");
        assertTrue(siloLens.isSolvent(silo1, borrower), "borrower is solvent @1");
        assertTrue(siloLens.inDebt(siloConfig, borrower), "borrower has debt now");

        assertTrue(siloLens.hasPosition(siloConfig, borrower), "borrower has position #0");
        assertTrue(siloLens.hasPosition(siloConfig, borrower), "borrower has position #1");

        assertEq(siloLens.getUserLTV(silo0, borrower), 0.75e18, "borrower LTV #0");
        assertEq(siloLens.getUserLTV(silo1, borrower), 0.75e18, "borrower LTV #1");

        assertEq(
            siloLens.collateralBalanceOfUnderlying(silo0, borrower),
            collateral,
            "collateralBalanceOfUnderlying after borrow"
        );

        vm.warp(block.timestamp + 65 days);

        assertFalse(siloLens.isSolvent(silo0, borrower), "borrower is NOT solvent @0");
        assertFalse(siloLens.isSolvent(silo1, borrower), "borrower is NOT solvent @1");

        assertEq(siloLens.liquidity(silo0), deposit0 + collateral, "liquidity in silo0 after borrow + time");

        assertLt(
            siloLens.liquidity(silo1),
            deposit1 - toBorrow,
            "liquidity in silo1 after borrow + time is less than deposit - borrow, because of interest"
        );

        assertEq(siloLens.getRawLiquidity(silo0), deposit0 + collateral, "getRawLiquidity 0 after borrow + time");
        assertEq(siloLens.getRawLiquidity(silo1), deposit1 - toBorrow, "getRawLiquidity 1 after borrow + time");

        assertEq(
            siloLens.collateralBalanceOfUnderlying(silo0, borrower),
            collateral,
            "collateralBalanceOfUnderlying"
        );

        vm.warp(block.timestamp + 300 days);

//        assertEq(siloLens.getBorrowAPR(silo0), 123, "getBorrowAPR");
//        assertEq(siloLens.getDepositAPR(silo0), 321, "getDepositAPR");

        assertTrue(siloLens.hasPosition(siloConfig, borrower), "hasPosition");


    }
}
