// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {stdError} from "forge-std/StdError.sol";

import {SafeCast} from "openzeppelin5/utils/math/SafeCast.sol";
import {IERC4626, IERC20} from "openzeppelin5/interfaces/IERC4626.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {ErrorsLib} from "../../contracts/libraries/ErrorsLib.sol";
import {EventsLib} from "../../contracts/libraries/EventsLib.sol";
import {ConstantsLib} from "../../contracts/libraries/ConstantsLib.sol";

import {IntegrationTest} from "./helpers/IntegrationTest.sol";
import {CAP, MAX_TEST_ASSETS, MIN_TEST_ASSETS, TIMELOCK} from "./helpers/BaseTest.sol";

/*
 FOUNDRY_PROFILE=vaults-tests forge test --ffi --mc MarketTest -vvv
*/
contract AuditDebugTest is IntegrationTest {

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

     Description: As the markets themselves are ERC4626, a share inflation attack (first depositor) in any of them may
     result in the vault being drained, as users can call the reallocateTo() or the deposit() functions to constantly
     deposit into the vulnerable ERC4626 and lose funds.

The way the standard implementation of ERC4626 deals with a first depositor attack is by making such attack unprofitable
 for an attacker, which will discourage anyone from actually inflating the share price. An attacker would need to invest
 a certain amount of funds in order to inflate the price, and that amount must be greater than any loss caused due to
 rounding to any future depositor.

The implied assumption is that the victim must be front-runned and will not repeat this deposit more than once.
This assumption does not actually hold true in our case because the attacker has some control over the Silo Vault.
 He can control how many times the vault deposits into the ERC4626 market, repeating this action as many times
 as he wants via the reallocateTo() function in the PublicAllocator.sol contract which would cost the attacker some fees,
 or via the deposit() function if the vulnerable market is the next market in the supplyQueue (This could be forced by
 taking a large flashloan and filling up the caps of the markets ahead of it in the queue), and controlling the amount
 that is being deposited (making it such that the rounding errors would be most impactful).



While it would be best for an attacker if he would be able to inflate the share price in any regular market (as he would
be able to be a shareholder in that market and gain the funds that the Silo Vault will lose), there’s no guarantee that
it would be possible. However, the Idle Vault should always be vulnerable to a share price inflation attack. It inherits
 from the standard ERC4626 implementation and it restricts anyone who isn't the Silo Vault from being a shareholder.
  In that case, the attacker can forcibly make the Silo Vault withdraw the funds from there (if caps allow it)
  and inflate the share price through a donation. After the inflation, the attacker can force the Silo Vault
   to deposit funds into the Idle Vault that will be lost due to rounding, causing a permanent loss of funds,
   as they will be owned by the “virtual attacker” in the Idle Vault.



Recommendations: Firstly, we would recommend adding a sanity check that whenever the Silo Vault deposits funds into
an ERC4626 market, the difference in Silo Vault-owned assets reported by the market is not too different from the
 amount that was actually deposited. Secondly, we would recommend setting the _decimalsOffset() in the Idle Vault to be
 very large (say, 18). This would make the amount that the attacker would need to "gift" the market in order to significantly
 inflate the share price very large and impractical.

Lastly, we would also recommend making a design change and cap the amounts that could be deposited
(decrease back when funds are withdrawn) into each market (and not just the amount that it currently holds
on the Silo Vault's behalf). This could limit any damage to the Silo Vault that could occur as a result of a faulty market.

     FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt testInflationAttackWithDonation -vvv

    - donation attack works but it is not profitable to attacker
    - however it can cause damage (founds loss + tokens locked)
    - if we want to protect from locked tokens, we can add rescue tokens to immutable address (when total supply == 0)

    - solution proposed by certora where we will check withdraw amount will work, but it will lock deposits after
     donation attack, so we will have to remove ide vault from queue (this may be general solution)

    - will offset 18 works? YES! looks like perfect solution (but only for our idle vault)

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
