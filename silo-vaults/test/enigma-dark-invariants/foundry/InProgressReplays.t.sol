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
 * Current Replays Under Analysis – Awaiting Review or Further Examination"
 */
contract InProgressReplays is BaseCryticToFoundry {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                  POSTCONDITIONS REPLAY                                    //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    // DONATIONS

    // ERC4626

    // ACCOUNTING

    function test_replay_2depositVault() public {
        // @audit-issue if underlying vault is open to donations, like in this case IdleVault, the protocol leaks assets since it deposits without receiving shares
        Tester.submitCap(10000000000000000, 3);
        _delay(605468);
        Tester.acceptCap(3);
        Tester.donateUnderlyingToSilo(640888064235293807253551779896804801047568146457797418729975, 3);
        Tester.setSupplyQueue(11);

        console.log("==========");
        console.log("vault.totalAssets(): ", vault.totalAssets());
        console.log("vault.lastTotalAssets(): ", vault.lastTotalAssets());
        console.log("==========");

        Tester.depositVault(1, 0);

        console.log("==========");
        console.log("vault.totalAssets(): ", vault.totalAssets());
        console.log("vault.lastTotalAssets(): ", vault.lastTotalAssets());
        console.log("==========");

        Tester.depositVault(1, 0);
    }

    function test_replay_transitionCollateral() public {
        // @audit-issue mismatch between lastTotalAssets and totalAssets after a call leads to wrong yield accounting in the suite
        Tester.submitCap(729479, 7);
        _delay(318197);
        _delay(291190);
        Tester.submitCap(1, 0);
        Tester.acceptCap(3);
        _delay(626639);
        Tester.acceptCap(0);
        Tester.setSupplyQueue(7);
        Tester.deposit(39, 0, 3);
        Tester.depositVault(2, 0);
        Tester.assert_ERC4626_DEPOSIT_INVARIANT_C();
        Tester.donateUnderlyingToSilo(56447107724879501408673723970558992484992870152700643, 3);
        Tester.withdrawVault(1, 0);
        Tester.transitionCollateral(1004, 0, 99, 3);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                     INVARIANTS REPLAY                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
