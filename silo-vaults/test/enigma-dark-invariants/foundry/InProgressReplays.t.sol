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

    // ERC4626 MAX deposit / Mint

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

    // ERC4626 ROUNDTRIP

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

    function test_replay_assert_ERC4626_ROUNDTRIP_INVARIANT_C() public {
        // @audit-issue Invalid: 395404>327236 failed, reason: ERC4626_ROUNDTRIP_INVARIANT_C: deposit(redeem(s)) <= s
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(332369);
        Tester.donateUnderlyingToSilo(1524785991, 71);
        _delay(332369);
        Tester.deposit(1524785993, 40, 255);
        _delay(305572);
        Tester.submitCap(1524785991, 114);
        _delay(415353);
        Tester.submitCap(4370001, 85);
        _delay(361136);
        Tester.acceptCap(58);
        _delay(358061);
        Tester.submitCap(4370001, 255);
        _setUpActor(0x0000000000000000000000000000000000020000);
        _delay(434894);
        Tester.donateSharesToVault(4370000, 102);
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(379552);
        Tester.acceptCap(255);
        _setUpActor(0x0000000000000000000000000000000000020000);
        _delay(322374);
        Tester.setSupplyQueue(122);
        _setUpActor(0x0000000000000000000000000000000000010000);
        Tester.acceptCap(229);
        _delay(67960);
        Tester.assert_ERC4626_MINT_INVARIANT_C();
        _delay(49735);
        Tester.setSupplyQueue(33);
        _delay(547623);
        Tester.assert_ERC4626_ROUNDTRIP_INVARIANT_C(327236);
    }

    // ACCOUNTING deposits / withdrawals

    function test_replay_4depositVault() public {
        // @audit-issue Invalid: 1!=0, reason: HSPOST_ACCOUNTING_C: After a deposit or mint, the totalAssets should increase by the amount deposited
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

    // ACCOUNTING totalAssets

    function test_replay_2withdrawFees() public {
        // @audit-issue GPOST_ACCOUNTING_A: totalAssets should always increase unless a withdrawal occurs
        Tester.deposit(1524785993, 24, 139);
        Tester.borrowSameAsset(4370001, 1, 79);
        Tester.submitCap(1177779859, 9);
        _delay(436727);
        Tester.donateSharesToVault(6636461356179863684125329761750295507025434252276924616483267239112809, 0);
        _delay(289607);
        Tester.acceptCap(1);
        Tester.setSupplyQueue(1);
        Tester.assert_ERC4626_ROUNDTRIP_INVARIANT_A(20);
        _delay(58368);
        Tester.depositVault(820905169, 0);
        _delay(36901);
        Tester.claimRewards();
        Tester.withdrawFees(7);
    }

    function test_replay_borrowSameAsset() public {
        // @audit-issue Invalid: 820905175<820905176 failed, reason: GPOST_ACCOUNTING_A: totalAssets should always increase unless a withdrawal occurs
        Tester.deposit(472326162, 123, 139);
        Tester.borrowSameAsset(4370001, 0, 13);
        Tester.submitCap(1315974944, 33);
        _delay(512439);
        _delay(120198);
        Tester.acceptCap(1);
        Tester.setSupplyQueue(1);
        _delay(12432);
        Tester.claimRewards();
        Tester.assert_ERC4626_ROUNDTRIP_INVARIANT_C(1066387);
        Tester.depositVault(820905169, 0);
        _delay(198598);
        Tester.borrowSameAsset(2, 0, 7);
    }

    function test_replay_2reallocateTo() public {
        // @audit-issue Invalid: 1<2 failed, reason: GPOST_ACCOUNTING_A: totalAssets should always increase unless a withdrawal occurs
        Tester.mint(182395, 0, 1);
        Tester.deposit(1554, 0, 123);
        Tester.submitCap(19402, 14);
        _delay(289103);
        Tester.submitCap(1, 1);
        _delay(321151);
        Tester.acceptCap(2);
        _delay(359157);
        Tester.donateSharesToVault(2034, 2);
        Tester.acceptCap(1);
        Tester.setFlowCaps(
            [
                FlowCaps(2, 2000999613920889324139923272930),
                FlowCaps(73688566600440228608076879, 251961596674309237310094453587804),
                FlowCaps(0, 15974),
                FlowCaps(16968530276661978480792371370807, 1278041159934950460843423752951418)
            ]
        );
        Tester.reallocateTo(
            1, [uint128(5148266763524718801906570585435046), uint128(712608292928486105902163280761023), uint128(31)]
        );
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                     INVARIANTS REPLAY                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
