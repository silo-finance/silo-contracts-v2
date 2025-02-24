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

contract ERC4626impl is ERC4626 {
    constructor(address _asset) ERC4626(IERC20(_asset)) ERC20("name", "symbol") {
    }
}
/*
 FOUNDRY_PROFILE=vaults-tests forge test --ffi --mc IdleVaultTest -vvv
*/
contract IdleVaultTest is IntegrationTest {
    ERC4626 erc4626;

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

        erc4626 = new ERC4626impl(address(vault.asset()));
    }

    /*
    FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt testInflationAttackWithDonation -vvv
    */
    function testInflationAttackWithDonation(
//        uint64 attackerDeposit, uint64 supplierDeposit, uint64 donation
    ) public {
        (uint64 attackerDeposit, uint64 supplierDeposit, uint64 donation) = (12345, 3.5e18, 14e18);
        vm.assume(uint256(attackerDeposit) * supplierDeposit * donation != 0);
        vm.assume(supplierDeposit >= 2);

        // we want some founds to go to idle market, so cap must be lower than deposit
        _setCap(allMarkets[0], supplierDeposit / 2);

        address attacker = makeAddr("attacker");

        vm.prank(attacker);
        vault.deposit(attackerDeposit, attacker);

        _printData("state after attacker deposit");

        IERC20(idleMarket.asset()).transfer(address(idleMarket), donation);

        _printData("state after donation");

        // we want cases where asset generates some shares
        vm.assume(vault.convertToShares(supplierDeposit) != 0);

        vm.prank(SUPPLIER);
        vault.deposit(supplierDeposit, SUPPLIER);

        _printData("after supplier deposit");

        vm.startPrank(attacker);
        uint256 attackerWithdraw = vault.redeem(vault.balanceOf(attacker), attacker, attacker);
        assertLe(attackerWithdraw, uint256(attackerDeposit) + donation, "must be not profitable");
        vm.stopPrank();

        _printData("after attacker exit");

        vm.startPrank(SUPPLIER);
        uint256 withdraw2 = vault.redeem(vault.balanceOf(SUPPLIER), SUPPLIER, SUPPLIER);

        _printData("after supplier exit");

        uint256 attackerTotalSpend = donation + attackerDeposit;
        emit log_named_uint("ATTACKER loss", attackerTotalSpend - attackerWithdraw);
        emit log_named_decimal_uint("ATTACKER lost [%]", (attackerTotalSpend - attackerWithdraw) * 1e18 / attackerTotalSpend, 16);

        // -2 because we allow for 2 wei rounding loss
        if (withdraw2 < supplierDeposit - 2) {
            emit log_named_uint("SUPPLIER lost", supplierDeposit - 2 - withdraw2);
            emit log_named_decimal_uint("SUPPLIER lost [%]", (supplierDeposit - 2 - withdraw2) * 1e18 / supplierDeposit, 16);
        }

        assertGe(
            withdraw2,
            supplierDeposit - 2,
            "there should be no loss (2 wei acceptable for two roundings)"
        );
        vm.stopPrank();
    }

    /*
    FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt testInflationAttack_permanentLoss -vvv

    1. withdraw from idle
    2. inflate price
    3. deposit to idle (loss?): yes, it is the same as donation

    setting up 18 (or even 36 offset) prevent it (for idle vault)

    */
    function testInflationAttack_permanentLoss(
//        uint64 attackerDeposit, uint64 supplierDeposit, uint64 donation
    ) public {
        (uint64 attackerDeposit, uint64 supplierDeposit, uint64 donation) = (12345, 3.5e18, 14e18);
        vm.assume(uint256(attackerDeposit) * supplierDeposit * donation != 0);
        vm.assume(supplierDeposit >= 2);

        // we want some founds to go to idle market, so cap must be lower than deposit
        _setCap(allMarkets[0], supplierDeposit / 2);

        vm.prank(SUPPLIER);
        vault.deposit(supplierDeposit, SUPPLIER);

        _printData("after supplier deposit");

        // simulate realocation (withdraw from idle)
        vm.startPrank(address(vault));
        uint256 idleAmount = idleMarket.redeem(idleMarket.balanceOf(address(vault)), address(vault), address(vault));
        vm.stopPrank();

        _printData("state after realoction from idle");

        address attacker = makeAddr("attacker");
        IERC20(idleMarket.asset()).transfer(address(idleMarket), donation);


        // simulate realocation back
        vm.startPrank(address(vault));
        idleMarket.deposit(idleAmount, address(vault));
        vm.stopPrank();

        _printData("state after realocation back to idle");
    }

    function _printData(string memory _msg) internal {
        address attacker = makeAddr("attacker");
        IERC20 asset = IERC20(allMarkets[0].asset());

        emit log(string.concat("\n----------------", _msg, "------------------"));

        emit log_named_uint("asset.balanceOf(allMarkets[0])", asset.balanceOf(address(allMarkets[0])));
        emit log_named_uint("   asset.balanceOf(idleMarket)", asset.balanceOf(address(idleMarket)));

        emit log_named_uint("   SUPPLIER vault shares", vault.balanceOf(SUPPLIER));
        emit log_named_uint("   attacker vault shares", vault.balanceOf(attacker));

        emit log_named_uint("     SUPPLIER preview withdraw", vault.previewRedeem(vault.balanceOf(SUPPLIER)));
        emit log_named_uint("     attacker preview withdraw", vault.previewRedeem(vault.balanceOf(attacker)));

        emit log_named_uint("  vault shares in market#0", allMarkets[0].balanceOf(address(vault)));
        emit log_named_uint("vault shares in idleMarket", idleMarket.balanceOf(address(vault)));

    }
}