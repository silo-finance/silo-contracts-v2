// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {SiloStorageLib} from "silo-core/contracts/lib/SiloStorageLib.sol";

import {SiloLittleHelper} from "../../../_common/SiloLittleHelper.sol";

import {Silo} from "silo-core/contracts/Silo.sol";
import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";
import {SiloHarness} from "silo-core/test/foundry/_mocks/SiloHarness.sol";

/*
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mc MaxBorrowAndFractions

    Testing scenarios and result with and without fix in the SiloLendingLib.sol.maxBorrowValueToAssetsAndShares fn
    // assets--;

    results for maxBorrow => borrow

    borrow 50
        scenario 1 - revert AboveMaxLtv (fix solves the issue)
        scenario 2 - revert AboveMaxLtv (fix solves the issue)
        scenario 3 - succeeds (no changes)

    borrow max / 2
        scenario 1 - revert AboveMaxLtv (fix solves the issue)
        scenario 2 - revert AboveMaxLt (fix solves the issue)
        scenario 3 - succeeds (no changes)

    borrow 0
        scenario 1 - revert AboveMaxLtv (fix solves the issue)
        scenario 2 - revert AboveMaxLtv (fix solves the issue)
        scenario 3 - succeeds (no changes)

    scenario 1 (interest 1 revenue 1)
        SiloHarness(payable(address(silo1))).increaseTotalDebtAssets(1);

    scenario 2 (interest 1 revenue 0)
        SiloHarness(payable(address(silo1))).increaseTotalDebtAssets(1);
        SiloHarness(payable(address(silo1))).increaseTotalCollateralAssets(1);

    scenario 3 (interest 0 revenue 1)
        SiloHarness(payable(address(silo1))).decreaseTotalCollateralAssets(1); 
*/
contract MaxBorrowAndFractions is SiloLittleHelper, Test {
    function setUp() public {
        ISiloConfig siloConfig = _setUpLocalFixture();

        assertTrue(siloConfig.getConfig(address(silo0)).maxLtv != 0, "we need borrow to be allowed");

        token0.setOnDemand(true);
        token1.setOnDemand(true);

        _doDeposit();
    }

    /*
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_maxBorrow_Borrow_WithFractions_scenario1

    scenario 1 - increase total debt assets
    */
    function test_maxBorrow_Borrow_WithFractions_scenario1() public {
        uint256 snapshot = vm.snapshot();

        uint256 borrowAmount = 50;
        address borrower = address(this);
        uint256 maxBorrowAfterDeposit;

        _borrowAndUpdateSiloCode(borrowAmount);
        SiloHarness(payable(address(silo1))).increaseTotalDebtAssets(1);
        silo1.borrow(borrowAmount, borrower, borrower);

        vm.revertTo(snapshot);

        borrowAmount = silo1.maxBorrow(borrower);
        maxBorrowAfterDeposit = _borrowAndUpdateSiloCode(borrowAmount / 2);
        SiloHarness(payable(address(silo1))).increaseTotalDebtAssets(1);
        silo1.borrow(maxBorrowAfterDeposit / 2, borrower, borrower);

        vm.revertTo(snapshot);

        maxBorrowAfterDeposit = _borrowAndUpdateSiloCode(0);
        SiloHarness(payable(address(silo1))).increaseTotalDebtAssets(1);
        silo1.borrow(maxBorrowAfterDeposit, borrower, borrower);

        vm.revertTo(snapshot);
    }

    /*
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_maxBorrow_Borrow_WithFractions_scenario2

    scenario 2 - increase total collateral and debt assets
    */
    function test_maxBorrow_borrow_WithFractions_scenario2() public {
        uint256 snapshot = vm.snapshot();

        uint256 borrowAmount = 50;
        address borrower = address(this);
        uint256 maxBorrowAfterDeposit;

        _borrowAndUpdateSiloCode(borrowAmount);
        SiloHarness(payable(address(silo1))).increaseTotalDebtAssets(1);
        SiloHarness(payable(address(silo1))).increaseTotalCollateralAssets(1);
        silo1.borrow(borrowAmount, borrower, borrower);

        vm.revertTo(snapshot);

        borrowAmount = silo1.maxBorrow(borrower);
        maxBorrowAfterDeposit = _borrowAndUpdateSiloCode(borrowAmount / 2);
        SiloHarness(payable(address(silo1))).increaseTotalDebtAssets(1);
        SiloHarness(payable(address(silo1))).increaseTotalCollateralAssets(1);
        silo1.borrow(maxBorrowAfterDeposit / 2, borrower, borrower);

        vm.revertTo(snapshot);

        maxBorrowAfterDeposit = _borrowAndUpdateSiloCode(0);
        SiloHarness(payable(address(silo1))).increaseTotalDebtAssets(1);
        SiloHarness(payable(address(silo1))).increaseTotalCollateralAssets(1);
        silo1.borrow(maxBorrowAfterDeposit, borrower, borrower);

        vm.revertTo(snapshot);
    }

    /*
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_maxBorrowWithFractions

    scenario 3 - decrease total collateral assets
    */
    function test_maxBorrowWithFractions_scenario3() public {
        uint256 snapshot = vm.snapshot();

        uint256 borrowAmount = 50;
        address borrower = address(this);
        uint256 maxBorrowAfterDeposit;

        _borrowAndUpdateSiloCode(borrowAmount);
        SiloHarness(payable(address(silo1))).decreaseTotalCollateralAssets(1);
        silo1.borrow(borrowAmount, borrower, borrower);

        vm.revertTo(snapshot);

        borrowAmount = silo1.maxBorrow(borrower);
        maxBorrowAfterDeposit = _borrowAndUpdateSiloCode(borrowAmount / 2);
        SiloHarness(payable(address(silo1))).decreaseTotalCollateralAssets(1);
        silo1.borrow(maxBorrowAfterDeposit / 2, borrower, borrower);

        vm.revertTo(snapshot);

        maxBorrowAfterDeposit = _borrowAndUpdateSiloCode(0);
        SiloHarness(payable(address(silo1))).decreaseTotalCollateralAssets(1);
        silo1.borrow(maxBorrowAfterDeposit, borrower, borrower);

        vm.revertTo(snapshot);
    }

    function _doDeposit() internal {
        silo0.mint(1e6, address(this));
        silo1.deposit(1e6, address(1));
    }

    function _borrowAndUpdateSiloCode(uint256 _amount) internal returns (uint256 maxBorrow) {
        address borrower = address(this);

        if (_amount != 0) {
            silo1.borrow(_amount, borrower, borrower);
        }

        address silo1Harness = address(new SiloHarness(ISiloFactory(address(this))));

        vm.etch(address(silo1), address(silo1Harness).code);

        ISilo.Fractions memory fractions = silo1.getFractionsStorage();
        emit log_named_uint("fractions.interest", fractions.interest);
        emit log_named_uint("fractions.revenue", fractions.revenue);

        maxBorrow = silo1.maxBorrow(borrower);
        emit log_named_uint("maxBorrow", maxBorrow);
    }
}
