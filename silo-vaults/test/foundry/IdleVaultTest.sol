// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {stdError} from "forge-std/StdError.sol";

import {ERC20, ERC4626} from "openzeppelin5/token/ERC20/extensions/ERC4626.sol";
import {SafeCast} from "openzeppelin5/utils/math/SafeCast.sol";
import {IERC4626, IERC20} from "openzeppelin5/interfaces/IERC4626.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {ErrorsLib} from "../../contracts/libraries/ErrorsLib.sol";
import {EventsLib} from "../../contracts/libraries/EventsLib.sol";
import {ConstantsLib} from "../../contracts/libraries/ConstantsLib.sol";

import {IntegrationTest} from "./helpers/IntegrationTest.sol";
import {CAP, MAX_TEST_ASSETS, MIN_TEST_ASSETS, TIMELOCK} from "./helpers/BaseTest.sol";

/*
 FOUNDRY_PROFILE=vaults-tests forge test --ffi --mc IdleVaultTest -vvv
*/
contract IdleVaultTest is IntegrationTest {
    address attacker = makeAddr("attacker");

    function setUp() public override {
        super.setUp();

        IERC4626[] memory supplyQueue = new IERC4626[](2);
        supplyQueue[0] = allMarkets[0];
        supplyQueue[1] = idleMarket;

        _setCap(allMarkets[0], 1);
        _setCap(idleMarket, type(uint128).max);

        vm.prank(ALLOCATOR);
        vault.setSupplyQueue(supplyQueue);

        assertEq(vault.supplyQueueLength(), 2, "only 2 markets");
        assertEq(address(vault.supplyQueue(1)), address(idleMarket), "ensure we have idle");
    }

    /*
    FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt test_idleVault_InflationAttackWithDonation -vvv

    TODO skipping that one, because offset itself does not help here, we need general solution for checking preview
    once this solution will be there, I will unskip test
    */
    function test_skip_idleVault_InflationAttackWithDonation(
        uint64 attackerDeposit, uint64 supplierDeposit, uint64 donation
    ) public {
//        (uint64 attackerDeposit, uint64 supplierDeposit, uint64 donation) = (162098118122, 25477955004, 898476375603394006);
        vm.assume(uint256(attackerDeposit) * supplierDeposit * donation != 0);
        vm.assume(supplierDeposit >= 2);

        // we want some founds to go to idle market, so cap must be lower than deposit
        _setCap(allMarkets[0], supplierDeposit / 2);

        vm.prank(attacker);
        vault.deposit(attackerDeposit, attacker);

        IERC20(idleMarket.asset()).transfer(address(idleMarket), donation);

        // we want cases where asset generates some shares
        vm.assume(vault.convertToShares(supplierDeposit) != 0);

        vm.prank(SUPPLIER);
        vault.deposit(supplierDeposit, SUPPLIER);

        uint256 attackerTotalSpend = uint256(donation) + attackerDeposit;

        vm.startPrank(attacker);
        uint256 attackerWithdraw = vault.redeem(vault.balanceOf(attacker), attacker, attacker);
        assertLe(attackerWithdraw, attackerTotalSpend, "must be not profitable");
        vm.stopPrank();

        vm.startPrank(SUPPLIER);
        uint256 supplierWithdraw = vault.redeem(vault.balanceOf(SUPPLIER), SUPPLIER, SUPPLIER);
        vm.stopPrank();

        uint256 attackerTotalLossPercent = (attackerTotalSpend - attackerWithdraw) * 1e18 / attackerTotalSpend;
        emit log_named_decimal_uint("attackerTotalLossPercent", attackerTotalLossPercent, 16);

        uint256 supplierDiff = supplierDeposit > supplierWithdraw
            ? supplierDeposit - supplierWithdraw
            : supplierWithdraw - supplierDeposit;

        emit log_named_uint("SUPPLIER diff", attackerTotalLossPercent);

        assertGe(
            supplierWithdraw,
            supplierDeposit - 2,
            "SUPPLIER should not lost (2 wei acceptable for roundings)"
        );
    }

    /*
    FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt test_idleVault_InflationAttack_permanentLoss -vvv

    1. withdraw from idle
    2. inflate price
    3. deposit to idle (loss?): yes, it is the same as donation

    */
    function test_idleVault_InflationAttack_permanentLoss(
        uint64 attackerDeposit, uint64 supplierDeposit, uint64 donation
    ) public {
//        (uint64 attackerDeposit, uint64 supplierDeposit, uint64 donation) = (12783837464301441318, 36, 18446744073709551614);
        vm.assume(uint256(attackerDeposit) * supplierDeposit * donation != 0);
        vm.assume(supplierDeposit >= 2);

        // we want some founds to go to idle market, so cap must be lower than deposit
        _setCap(allMarkets[0], supplierDeposit / 2);

        vm.prank(SUPPLIER);
        vault.deposit(supplierDeposit, SUPPLIER);

        // simulate realocation (withdraw from idle)
        vm.startPrank(address(vault));
        uint256 idleAmount = idleMarket.redeem(idleMarket.balanceOf(address(vault)), address(vault), address(vault));
        vm.stopPrank();

        // inflate price
        IERC20(idleMarket.asset()).transfer(address(idleMarket), donation);

        // simulate realocation back
        vm.startPrank(address(vault));
        idleMarket.deposit(idleAmount, address(vault));
        vm.stopPrank();

        vm.startPrank(SUPPLIER);
        uint256 supplierWithdraw = vault.redeem(vault.balanceOf(SUPPLIER), SUPPLIER, SUPPLIER);
        vm.stopPrank();

        assertGe(
            supplierWithdraw,
            supplierDeposit - 2,
            "SUPPLIER should not lost (2 wei acceptable for roundings)"
        );
    }
}
