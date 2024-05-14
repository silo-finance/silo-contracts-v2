// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";

import {SiloFixture} from "../../_common/fixtures/SiloFixture.sol";
import {MintableToken} from "../../_common/MintableToken.sol";
import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc BorrowNotPossibleTest
*/
contract BorrowNotPossibleTest is SiloLittleHelper, Test {
    bool sameAsset;

    function setUp() public {
        _setUpLocalFixture(SiloConfigsNames.LOCAL_NOT_BORROWABLE);

        (
            ISiloConfig.ConfigData memory cfg0, ISiloConfig.ConfigData memory cfg1,
        ) = silo0.config().getConfigs(address(silo0), address(0), 0 /* always 0 for external calls */);

        assertEq(cfg0.maxLtv, 0, "borrow OFF");
        assertGt(cfg1.maxLtv, 0, "borrow ON");
    }

    /*
    forge test -vv --ffi --mt test_borrow_possible_for_token0
    */
    function test_borrow_possible_for_token0() public {
        uint256 depositAssets = 1e18;
        address borrower = makeAddr("Borrower");
        address depositor = makeAddr("Depositor");

        _deposit(depositAssets, depositor, ISilo.CollateralType.Collateral);
        _depositForBorrow(depositAssets, borrower);

        vm.prank(borrower);
        silo0.borrow(1, borrower, borrower, sameAsset);
    }

    /*
    forge test -vv --ffi --mt test_borrow_not_possible_for_token1
    */
    function test_borrow_not_possible_for_token1() public {
        uint256 depositAssets = 1e18;
        address borrower = makeAddr("Borrower");
        address depositor = makeAddr("Depositor");

        _deposit(depositAssets, borrower, ISilo.CollateralType.Collateral);
        _depositForBorrow(depositAssets, depositor);

        vm.prank(borrower);
        vm.expectRevert(ISilo.AboveMaxLtv.selector);
        silo1.borrow(1, borrower, borrower, sameAsset);
    }

    /*
    FOUNDRY_PROFILE=core-test forge test -vv --ffi --mt test_borrow_without_collateral
    */
    /// forge-config: core-test.fuzz.runs = 1000
    function test_borrow_without_collateral(uint256 _depositAmount, uint256 _borrowAmount) public {
        vm.assume(_borrowAmount > 0);
        vm.assume(_depositAmount > _borrowAmount);

        address depositor = makeAddr("Depositor");

        _depositForBorrow(_depositAmount, depositor);

        vm.expectRevert(ISilo.AboveMaxLtv.selector);
        _borrow(_borrowAmount, address(this), sameAsset);
    }
}
