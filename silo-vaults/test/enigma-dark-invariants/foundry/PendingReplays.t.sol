// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries
import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {
    FlowCaps,
    FlowCapsConfig,
    Withdrawal,
    MAX_SETTABLE_FLOW_CAP,
    IPublicAllocatorStaticTyping,
    IPublicAllocatorBase
} from "silo-vaults/contracts/interfaces/IPublicAllocator.sol";

// Contracts
import {BaseCryticToFoundry} from "../base/BaseCryticToFoundry.t.sol";

/*
 * Replays for Future Review – Interesting, Yet to be Fully Analyzed
 */
contract PendingReplays is BaseCryticToFoundry {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                  POSTCONDITIONS REPLAY                                    //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    // DONATIONS

    function test_replay_depositVault() public {
        /// @dev discarded
        vm.skip(true);
        // @audit-issue amounts donated to idleVault skew the exchange rate
        // Drastic change in exchange rate
        Tester.submitCap(1, 3);
        _delay(300400);
        _delay(314034);
        Tester.acceptCap(3);
        Tester.setSupplyQueue(131);
        Tester.depositVault(1, 0);
        Tester.donateUnderlyingToSilo(24244493425189653970967633769294996162695044172722878947969214851, 3); // idle vault assets 24244493425189653970967633769294996162695044172722878947969214851 shares
        Tester.withdrawVault(16362308469563993950950965155643540714247646454230, 0);
        Tester.depositVault(1, 0);
        Tester.redeemVault(1, 0);
    }

    function test_replay_withdrawVault() public {
        /// @dev discarded
        vm.skip(true);
        // @audit-issue amounts donated to idleVault skew the exchange rate
        // Drastic change in exchange rate after donation
        Tester.submitCap(1, 3);
        _delay(300400);
        _delay(314034);
        Tester.acceptCap(3);
        Tester.setSupplyQueue(131);
        Tester.depositVault(1, 0);
        Tester.donateUnderlyingToSilo(24244493425189653970967633769294996162695044172722878947969214851, 3); // idle vault assets 24244493425189653970967633769294996162695044172722878947969214851 shares
        Tester.withdrawVault(16362308469563993950950965155643540714247646454230, 0);
        Tester.depositVault(1, 0);
    }

    function test_replay_redeemVault() public {
        /// @dev discarded
        vm.skip(true);
        // @audit-issue amounts donated to idleVault skew the exchange rate
        Tester.submitCap(1, 3);
        _delay(317245);
        _delay(291843);
        Tester.acceptCap(3);
        Tester.setSupplyQueue(11);
        Tester.depositVault(1, 0);
        Tester.donateUnderlyingToSilo(2, 3);
        Tester.redeemVault(1, 0);
    }

    // ERC4626

    function test_replay_assert_ERC4626_ROUNDTRIP_INVARIANT_C() public {
        /// @dev discarded
        vm.skip(true);
        // @audit-issue deposit(redeem(s)) > s, this breaks ERC4626_ROUNDTRIP_INVARIANT_C
        // Current exmaple: 2 > 1
        Tester.submitCap(2, 3);
        _delay(610502);
        Tester.acceptCap(3);
        Tester.setSupplyQueue(11);
        Tester.mintVault(1, 0);
        Tester.donateUnderlyingToSilo(1, 3);
        Tester.assert_ERC4626_ROUNDTRIP_INVARIANT_C(1);
    }

    function test_replay_assert_ERC4626_ROUNDTRIP_INVARIANT_H() public {
        /// @dev discarded
        vm.skip(true);
        // @audit-issue withdraw(a) >= deposit(a), withdraw and deposit the same amount of assets should lead to less minted shares on deposits than shares withdrawn
        // Current example: MintedShares = 432630000, RedeemedShares = 2351250
        Tester.donateUnderlyingToSilo(332, 7);
        Tester.submitCap(194372896, 255);
        _delay(318197);
        Tester.borrow(10820036174637966842933729450133966548961359954547416409062804080542, 0, 0);
        _delay(291190);
        Tester.submitCap(1421118, 0);
        Tester.acceptCap(3);
        _delay(626639);
        Tester.acceptCap(0);
        Tester.setSupplyQueue(27);
        Tester.assert_ERC4626_MINT_INVARIANT_C();
        Tester.donateUnderlyingToSilo(2977, 27);
        Tester.assert_ERC4626_WITHDRAW_INVARIANT_C();
        Tester.assert_ERC4626_ROUNDTRIP_INVARIANT_C(23882);
        Tester.assert_ERC4626_ROUNDTRIP_INVARIANT_C(33035);
        Tester.mintVault(197, 1);
        Tester.assert_ERC4626_ROUNDTRIP_INVARIANT_H(4370000);
    }

    function test_replay_assert_ERC4626_ROUNDTRIP_INVARIANT_D() public {
        /// @dev discarded
        vm.skip(true);
        // @audit-issue ERC4626_ROUNDTRIP_INVARIANT_D: a = redeem(s) a' = mint(s), a' >= a"
        // redeeming and then minting the same number of shares on the same transaction shouldnt leave the user with more assets deposited for the same amount of shares
        Tester.submitCap(9062025, 11);
        _delay(318197);
        _delay(291190);
        Tester.submitCap(1, 0);
        Tester.acceptCap(3);
        _delay(621091);
        Tester.acceptCap(0);
        Tester.setSupplyQueue(7);
        Tester.donateUnderlyingToSilo(1650, 3);
        Tester.mintVault(4370000, 0);
        Tester.assert_ERC4626_ROUNDTRIP_INVARIANT_D(4370001);
    }

    // ACCOUNTING

    function test_replay_2withdrawVault() public {
        /// @dev discarded
        vm.skip(true);
        //@audit-issue Similar case to test_replay_2depositVault, 1 asset is deposited in IdleVault but no shares are minted, however lastTotalAssets accounts 1 asset
        Tester.donateUnderlyingToSilo(1822, 3);
        Tester.submitCap(1, 3);
        _delay(611219);
        console.log("vault.totalAssets(): ", vault.totalAssets());
        console.log("vault.totalSupply(): ", vault.totalSupply());
        console.log("vault.lastTotalAssets(): ", vault.lastTotalAssets());
        Tester.acceptCap(3);
        console.log("vault.totalAssets(): ", vault.totalAssets());
        console.log("vault.totalSupply(): ", vault.totalSupply());
        console.log("vault.lastTotalAssets(): ", vault.lastTotalAssets());
        Tester.setSupplyQueue(11);
        console.log("vault.totalAssets(): ", vault.totalAssets());
        console.log("vault.totalSupply(): ", vault.totalSupply());
        console.log("vault.lastTotalAssets(): ", vault.lastTotalAssets());
        Tester.assert_ERC4626_MINT_INVARIANT_C();
        console.log("vault.totalAssets(): ", vault.totalAssets());
        console.log("vault.totalSupply(): ", vault.totalSupply());
        console.log("vault.lastTotalAssets(): ", vault.lastTotalAssets());
        Tester.withdrawVault(0, 0);
    }

    function test_replay_3mintVault() public {
        // @audit check why this is not reverting
        Tester.submitCap(1, 1);
        _delay(611025);
        Tester.acceptCap(1);
        Tester.setSupplyQueue(1);
        console.log("==========");
        console.log("vault.totalAssets(): ", vault.totalAssets());
        console.log("vault.lastTotalAssets(): ", vault.lastTotalAssets());
        console.log("==========");

        Tester.mint(3, 0, 3);
        console.log("==========");
        console.log("vault.totalAssets(): ", vault.totalAssets());
        console.log("vault.lastTotalAssets(): ", vault.lastTotalAssets());
        console.log("==========");

        Tester.mintVault(1, 0);
        console.log("==========");
        console.log("vault.totalAssets(): ", vault.totalAssets());
    }

    function test_replay_2reallocateTo() public {
        //@audit check why this is not failing in foundry
        Tester.submitCap(1, 1);
        _delay(611025);
        Tester.submitCap(1, 0);
        Tester.acceptCap(1);
        _delay(624208);
        Tester.acceptCap(0);
        Tester.setSupplyQueue(12);
        Tester.deposit(43698, 0, 3);
        Tester.mintVault(1, 0);
        Tester.borrowSameAsset(33988, 0, 3);
        _delay(8259);
        Tester.setFlowCaps(
            [
                FlowCaps(43, 1),
                FlowCaps(1, 0),
                FlowCaps(0, 0),
                FlowCaps(1164210329040005621302952752, 107674377076781863601164)
            ]
        );
        Tester.reallocateTo(1, [uint128(0), uint128(0), uint128(337189132338989816015415173)]);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                     INVARIANTS REPLAY                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
