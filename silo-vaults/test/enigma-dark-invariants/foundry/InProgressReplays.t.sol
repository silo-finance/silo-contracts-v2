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

    // ERC4626

    function test_replay_assert_ERC4626_DEPOSIT_INVARIANT_C() public {
        // @audit-issue maxDeposit does not contemplate new Losscheck
        // ERC4626_DEPOSIT_INVARIANT_C: maxDeposit MUST return the maximum amount of assets deposit would allow to be deposited for receiver and not cause a revert
        Tester.submitCap(1030317, 3);
        _delay(283936);
        _delay(322318);
        Tester.acceptCap(3);
        Tester.setSupplyQueue(11);
        Tester.donateUnderlyingToSilo(1881433619573894594259887001237445621086680812, 3);
        Tester.assert_ERC4626_DEPOSIT_INVARIANT_C();
    }

    function test_replay_assert_3ERC4626_MINT_INVARIANT_C() public {
        // @audit-issue maxDeposit does not contemplate new Losscheck
        // ERC4626_MINT_INVARIANT_C: maxMint MUST return the maximum amount of shares mint would allow to be deposited to receiver and not cause a revert
        Tester.donateUnderlyingToSilo(1025919756739, 3);
        Tester.submitCap(1012300, 3);
        _delay(614104);
        Tester.acceptCap(3);
        Tester.setSupplyQueue(11);
        Tester.assert_ERC4626_MINT_INVARIANT_C();
    }

    function test_replay_assert_ERC4626_ROUNDTRIP_INVARIANT_H() public {
        //@audit-issue Invalid: 4370004370000>2185002185000 failed, reason: ERC4626_ROUNDTRIP_INVARIANT_H: s = withdraw(a), s' = deposit(a), s' <= s
        Tester.donateUnderlyingToSilo(4369999, 3);
        Tester.submitCap(4522754, 3);
        Tester.submitCap(1, 1);
        _delay(611025);
        Tester.submitCap(1, 0);
        Tester.acceptCap(1);
        _delay(608222);
        Tester.acceptCap(0);
        Tester.setSupplyQueue(1);
        Tester.mintVault(1, 0);
        Tester.acceptCap(3);
        Tester.setSupplyQueue(3);
        Tester.assert_ERC4626_ROUNDTRIP_INVARIANT_H(4370000);
    }

    function test_replay_assert_ERC4626_ROUNDTRIP_INVARIANT_G() public {
        // @audit-issue Invalid: 2185000<4370000 failed, reason: ERC4626_ROUNDTRIP_INVARIANT_G: mint(withdraw(a)) >= a
        Tester.submitCap(1, 1);
        _delay(611025);
        Tester.submitCap(1, 0);
        Tester.acceptCap(1);
        _delay(614650);
        Tester.acceptCap(0);
        Tester.setSupplyQueue(1);
        Tester.mintVault(1, 0);
        Tester.submitCap(4866162, 31);
        _delay(135543);
        Tester.setFlowCaps(
            [
                FlowCaps(149417630983255636735380602335, 0),
                FlowCaps(1837238724402924527028129218826, 0),
                FlowCaps(0, 1),
                FlowCaps(0, 287762046071675232373809001107051)
            ]
        );
        _delay(415353);
        Tester.switchCollateralToThisSilo(0);
        _delay(59388);
        Tester.acceptCap(3);
        Tester.donateUnderlyingToSilo(4369999, 19);
        Tester.setSupplyQueue(3);
        Tester.assert_ERC4626_ROUNDTRIP_INVARIANT_G(4370000);
    }

    // ACCOUNTING

    function test_replay_4depositVault() public {
        // Invalid: 1!=0, reason: HSPOST_ACCOUNTING_C: After a deposit or mint, the totalAssets should increase by the amount deposited
        Tester.submitCap(1, 3);
        _delay(605468);
        Tester.acceptCap(3);
        Tester.donateUnderlyingToSilo(47866850693725092545, 3);
        Tester.setSupplyQueue(11);
        Tester.depositVault(1, 0);
    }

    function test_replay_3mintVault() public {
        // Invalid: 1!=0, reason: HSPOST_ACCOUNTING_C: After a deposit or mint, the totalAssets should increase by the amount deposited
        Tester.submitCap(255, 3);
        _delay(318197);
        _delay(291190);
        Tester.submitCap(1, 0);
        Tester.acceptCap(3);
        _delay(621091);
        Tester.acceptCap(0);
        Tester.setSupplyQueue(7);
        Tester.donateUnderlyingToSilo(2, 3);
        Tester.mintVault(5, 0);
    }

    function test_replay_5withdrawVault() public {
        // @audit-issue Invalid: 148235222114349712332047095248517940089058!=148235147996701596333132929767887575514906, reason: HSPOST_ACCOUNTING_D: After a withdraw or redeem, the totalAssets should decrease by the amount withdrawn
        Tester.submitCap(1, 3);
        _delay(295021);
        _delay(310505);
        Tester.acceptCap(3);
        Tester.setSupplyQueue(11);
        Tester.depositVault(1, 0);
        Tester.donateUnderlyingToSilo(296470444228699424664094190497035880178117, 3);
        Tester.withdrawVault(1, 0);
    }

    function test_replay_redeemVault() public {
        //@audit-issue Invalid: 88856874676256591473675988775164714407433366307!=88856852462015708174198381099384714238173540189, reason: HSPOST_ACCOUNTING_D: After a withdraw or redeem, the totalAssets should decrease by the amount withdrawn
        Tester.submitCap(1, 3);
        _delay(317490);
        _delay(287824);
        Tester.acceptCap(3);
        Tester.setSupplyQueue(11);
        Tester.depositVault(1, 0);
        Tester.donateUnderlyingToSilo(177713838209432287663495809298234077931905698565, 3);
        Tester.redeemVault(1, 0);
    }

    // BUGGED REPLAYS

    function test_replay_2reallocateTo() public {
        // TODO check why this reverts in echidna but not in
        // Invalid: 0<1 failed, reason: GPOST_ACCOUNTING_A: totalAssets should always increase unless a withdrawal occurs
        Tester.submitCap(1, 1);
        _delay(611025);
        Tester.submitCap(1, 0);
        Tester.acceptCap(1);
        _delay(621878);
        Tester.acceptCap(0);
        Tester.setSupplyQueue(12);
        Tester.deposit(34550, 0, 3);
        Tester.mintVault(1, 0);
        Tester.borrowSameAsset(25818, 0, 3);
        Tester.setFlowCaps(
            [
                FlowCaps(40335021944728680946129100601457107, 5),
                FlowCaps(1153792200385088713581931128542273, 372),
                FlowCaps(0, 8643),
                FlowCaps(0, 41934776819969954726385498882748940)
            ]
        );
        _delay(11692);
        Tester.reallocateTo(
            1, [uint128(0), uint128(64602806634386535667174091600377), uint128(68826297618660977371916128251)]
        );
    }

    function test_replay_withdrawFees() public {
        // TODO check why this reverts in echidna but not in foundry
        // Invalid: 2010604<2010605 failed, reason: GPOST_ACCOUNTING_A: totalAssets should always increase unless a withdrawal occurs
        Tester.submitCap(1, 1);
        _delay(127251);
        Tester.deposit(1012732488, 78, 188);
        _delay(490446);
        Tester.acceptCap(1);
        Tester.submitCap(51681381, 69);
        _delay(414579);
        Tester.deposit(4370001, 255, 255);
        Tester.mint(1524785993, 63, 255);
        _delay(352626);
        Tester.setSupplyQueue(21);
        Tester.acceptCap(45);
        Tester.borrow(2856892, 141, 97);
        Tester.assert_ERC4626_MINT_INVARIANT_C();
        _delay(336113);
        Tester.donateUnderlyingToSilo(36571, 45);
        _delay(67703);
        Tester.onERC721Received(address(0), address(0), 57406029, "");
        Tester.depositVault(2008655, 22);
        _delay(318197);
        Tester.approve(2354381657608461442095472565996231246535041913832423155980856080700948501023, 0, 0);
        _delay(1900714);
        Tester.withdrawFees(153);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                     INVARIANTS REPLAY                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
