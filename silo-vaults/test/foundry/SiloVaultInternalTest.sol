// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {UtilsLib} from "morpho-blue/libraries/UtilsLib.sol";

import {ErrorsLib} from "../../contracts/libraries/ErrorsLib.sol";
import {SiloVaultActionsLib} from "../../contracts/libraries/SiloVaultActionsLib.sol";
import {InternalTest} from "./helpers/InternalTest.sol";
import {NB_MARKETS, CAP, MIN_TEST_ASSETS, MAX_TEST_ASSETS} from "./helpers/BaseTest.sol";

/*
 FOUNDRY_PROFILE=vaults_tests forge test --ffi --mc SiloVaultInternalTest -vvv
*/
contract SiloVaultInternalTest is InternalTest {
    /*
     FOUNDRY_PROFILE=vaults_tests forge test --ffi --mt testSetCapMaxQueueLengthExcedeed -vvv
    */
    function testSetCapMaxQueueLengthExcedeed() public {
        for (uint256 i; i < NB_MARKETS - 1; ++i) {
            _setCap(allMarkets[i], CAP);
        }

        vm.expectRevert(ErrorsLib.MaxQueueLengthExceeded.selector);
        _setCap(allMarkets[NB_MARKETS - 1], CAP);
    }

    /*
     FOUNDRY_PROFILE=vaults_tests forge test --ffi --mt testSimulateWithdraw -vvv
    */
    function testSimulateWithdraw(uint256 suppliedAmount, uint256 borrowedAmount, uint256 assets) public {
        collateralToken.setOnDemand(true);
        loanToken.setOnDemand(true);

        suppliedAmount = bound(suppliedAmount, MIN_TEST_ASSETS, MAX_TEST_ASSETS);
        borrowedAmount = bound(borrowedAmount, MIN_TEST_ASSETS, suppliedAmount);

        _setCap(allMarkets[0], CAP);
        supplyQueue = [allMarkets[0]];

        vm.prank(SUPPLIER);
        this.deposit(suppliedAmount, SUPPLIER);

        uint256 collateral = suppliedAmount / 2;

        vm.startPrank(BORROWER);
        silo0.deposit(collateral, BORROWER);
        silo1.borrow(silo1.maxBorrow(BORROWER), BORROWER, BORROWER);
        vm.stopPrank();

        uint256 remaining = SiloVaultActionsLib.simulateWithdrawERC4626(assets, withdrawQueue);
        uint256 expectedWithdrawable = allMarkets[0].maxWithdraw(address(this));
        uint256 expectedRemaining = UtilsLib.zeroFloorSub(assets, expectedWithdrawable);

        assertEq(remaining, expectedRemaining, "remaining");
    }
}
