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

    // lastTotalAssets == totalAssets

    function test_replay_depositVault() public {
        //vm.skip(true);
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
        //vm.skip(true);
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

    function test_replay_2withdrawVault() public {
        //vm.skip(true);
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

    function test_replay_2depositVault() public {
        // @audit Invalid: 1!=0, reason: GPOST_ACCOUNTING_E: after any transaction lastTotalAssets == totalAssets
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

    function test_replay_3depositVault() public {
        //@audit Invalid: 1!=0, reason: GPOST_ACCOUNTING_E: after any transaction lastTotalAssets == totalAssets
        Tester.submitCap(1, 3);
        _delay(605468);
        Tester.acceptCap(3);
        Tester.donateUnderlyingToSilo(38402189825042237693731901551611295164383348807, 3);
        Tester.setSupplyQueue(11);
        Tester.depositVault(1, 0);
    }

    function test_replay_3withdrawVault() public {
        // @audit-issue Invalid: 28223553862439750704336861985279496242496435076350322!=28223553862439750690225085054059620883272115618100637, reason: GPOST_ACCOUNTING_E: after any transaction lastTotalAssets == totalAssets
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
    }

    function test_replay_4withdrawVault() public {
        // @audit Invalid: 230392031971866015168019583301510366752047031433284684075!=230392031971866015052823567315578114415758118497916303206, reason: GPOST_ACCOUNTING_E: after any transaction lastTotalAssets == totalAssets
        Tester.submitCap(1, 3);
        _delay(300400);
        _delay(309040);
        Tester.acceptCap(3);
        Tester.setSupplyQueue(11);
        Tester.depositVault(1, 0);
        Tester.donateUnderlyingToSilo(460784063943732030336039166603023754725369609699984104070, 3);
        Tester.withdrawVault(1510610637773416707367961, 0);
    }

    function test_replay_2redeemVault() public {
        // @audit Invalid: 34341990213282102359077078394754175612278313744476171470413569491544064842!=34341990213282102359077078394754175612278313744476171470413569491544064841, reason: GPOST_ACCOUNTING_E: after any transaction lastTotalAssets == totalAssets
        Tester.submitCap(1, 3);
        _delay(317490);
        Tester.accrueInterest(0);
        _delay(287824);
        Tester.acceptCap(3);
        Tester.setSupplyQueue(11);
        Tester.depositVault(1, 0);
        Tester.donateUnderlyingToSilo(68718339596362385911109711645331016732923089033469077479566922444310284824, 3);
        Tester.redeemVault(1, 0);
    }

    // ERC4626

    function test_replay_assert_ERC4626_ROUNDTRIP_INVARIANT_D() public {
        /// @dev discarded
        //vm.skip(true);
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

    function test_replay_assert_2ERC4626_ROUNDTRIP_INVARIANT_H() public {
        // @audit Invalid: 4374370000>2187185000 failed, reason: ERC4626_ROUNDTRIP_INVARIANT_H: s = withdraw(a), s' = deposit(a), s' <=
        Tester.donateUnderlyingToSilo(4369999, 15);
        Tester.submitCap(6483266, 3);
        Tester.submitCap(1, 1);
        _delay(611025);
        Tester.submitCap(1, 0);
        Tester.acceptCap(1);
        _delay(624208);
        Tester.acceptCap(0);
        Tester.setSupplyQueue(1);
        Tester.mintVault(1, 0);
        Tester.acceptCap(7);
        Tester.setSupplyQueue(3);
        Tester.assert_ERC4626_ROUNDTRIP_INVARIANT_H(4370000);
    }

    function test_replay_2assert_ERC4626_ROUNDTRIP_INVARIANT_G() public {
        // @audit Invalid: 2185000<4370000 failed, reason: ERC4626_ROUNDTRIP_INVARIANT_G: mint(withdraw(a)) >= a
        Tester.submitCap(1, 1);
        _delay(611025);
        Tester.submitCap(1, 0);
        Tester.acceptCap(1);
        _delay(624208);
        Tester.acceptCap(0);
        Tester.setSupplyQueue(1);
        Tester.mintVault(1, 0);
        Tester.submitCap(4866162, 31);
        _delay(135543);
        Tester.setFlowCaps(
            [
                FlowCaps(4932401098595547125942880655070664783, 1980),
                FlowCaps(293801568509871373585762159289216448, 231),
                FlowCaps(0, 4330),
                FlowCaps(0, 388239986960132788803191416457909070)
            ]
        );
        _delay(415353);
        Tester.switchCollateralToThisSilo(0);
        _delay(59388);
        Tester.acceptCap(27);
        Tester.donateUnderlyingToSilo(4369999, 19);
        Tester.setSupplyQueue(3);
        Tester.assert_ERC4626_ROUNDTRIP_INVARIANT_G(4370000);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                     INVARIANTS REPLAY                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
