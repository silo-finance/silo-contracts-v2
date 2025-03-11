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
 * Replays that have already been reviewed and resolved
 */
contract ResolvedReplays is BaseCryticToFoundry {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                  POSTCONDITIONS REPLAY                                    //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function test_replay_2redeem() public {
        Tester.submitCap(1, 0);
        _delay(557906);
        _delay(47130);
        Tester.acceptCap(0);
        Tester.setSupplyQueue(196);
        Tester.mintVault(1, 0);
        Tester.deposit(3440, 9, 3);
        Tester.redeem(1178, 0, 3);
    }

    function test_replay_2withdraw() public {
        Tester.mint(314578, 0, 3);
        Tester.submitCap(418, 0);
        _delay(692162);
        Tester.acceptCap(0);
        Tester.setSupplyQueue(16);
        Tester.assert_ERC4626_MINT_INVARIANT_C();
        Tester.withdraw(11, 0, 3);
    }

    function test_replay_assert_ERC4626_ROUNDTRIP_INVARIANT_G() public {
        /// @dev assert_ERC4626_ROUNDTRIP_INVARIANT_G
        // @audit-ok  mint(withdraw(a)) >= a,
        // Current example: assets required to mint 1, initial assets 2, since 1 < 2 breaks the invariant above
        Tester.submitCap(3882, 3);
        _delay(621798);
        Tester.acceptCap(3);
        Tester.setSupplyQueue(11);
        Tester.mintVault(1, 0);
        Tester.donateUnderlyingToSilo(1, 3);
        Tester.assert_ERC4626_ROUNDTRIP_INVARIANT_G(2);
    }

    function test_replay_mintVault() public {
        // @audit-ok amounts donated to idleVault skew the exchange rate
        Tester.submitCap(1, 3);
        _delay(623553);
        Tester.acceptCap(3);
        Tester.donateUnderlyingToSilo(1, 3);
        Tester.setSupplyQueue(11);
        Tester.mintVault(1, 0);
    }

    function test_replay_reallocateTo() public {
        // @audit-ok when reallocating, due to rounding and the use of withdraw instead of redeem, assets are lost in the vault without the protocol owning shares for those assets
        // ACCOUNTING BEFORE reallocating:  MARKET 1 (1000 shares, 2 assets), MARKET 2 (0 shares, 0 assets)
        // reallocating 1 asset from MARKET 1 to MARKET 2
        // ACCOUNTING BEFORE reallocating:  MARKET 1 (0 shares, 1 assets lost in the market), MARKET 2 (1000 shares, 1 assets)
        // This is due to SIlos not following the ERC4626 spec fully, convertToShares is meant to round alway down however in Silo's DEPOSIT_TO_ASSETS rounds to ceiling,
        // Metamorpho round down for all shares to assets conversions
        // Assuming silo codebase cannot be changed Silo vault could rely on previewRedeem function instead
        Tester.submitCap(1, 1);
        _delay(611025);
        Tester.submitCap(1, 0);
        Tester.acceptCap(1);
        _delay(624208);
        Tester.acceptCap(0);
        Tester.setSupplyQueue(12);
        Tester.deposit(46106, 0, 3);
        Tester.mintVault(1, 0);
        console.log("============");
        Tester.borrowSameAsset(33988, 0, 3);
        _delay(8657);
        _logWithdrawalQueue();
        Tester.setFlowCaps(
            [
                FlowCaps(8073, 1),
                FlowCaps(12041, 0),
                FlowCaps(133, 0),
                FlowCaps(10762493815665137267589636233636, 20295620084798062581032678405)
            ]
        );

        Tester.reallocateTo(5, [uint128(95170), uint128(371), uint128(5173979839362585723010800758195946)]);
        console.log("defaultVarsBefore.totalAssets: ", defaultVarsBefore.totalAssets);
        console.log("defaultVarsBefore.totalSupply: ", defaultVarsBefore.totalSupply);
        console.log("defaultVarsAfter.totalAssets: ", defaultVarsAfter.totalAssets);
        console.log("defaultVarsAfter.totalSupply: ", defaultVarsAfter.totalSupply);
        _logWithdrawalQueue();
    }

    function test_replay_3withdrawVault() public {
        // @audit-ok
        // Inconsistency in asset tracking after withdrawals
        //
        // Before calling donateUnderlyingToSilo:
        //      - vault.totalAssets(): 1
        //      - vault.totalSupply(): 1
        //      - vault.lastTotalAssets(): 1
        // After calling donateUnderlyingToSilo with 2 assets:
        //      - vault.totalAssets(): 2
        //      - vault.totalSupply(): 1
        //      - vault.lastTotalAssets(): 1
        //
        // After withdrawing 1 asset from the vault:
        //      - vault.totalAssets(): 0
        //      - vault.totalSupply(): 0
        //      - vault.lastTotalAssets(): 1
        //
        // Summary:
        // The protocol fails to fully account for all assets during withdrawals.
        // Although there are 2 assets to withdraw, only 1 is withdrawn in the final transaction,
        // leaving 1 asset stranded in the underlying vault without corresponding shares.
        //
        // Issue:
        // Violates GPOST_ACCOUNTING_D:
        //      - Expected: lastTotalAssets() == totalAssets() after any transaction.
        //      - Actual: lastTotalAssets() still tracks the lost wei, while totalAssets()
        //        no longer includes it since the SiloVault holds no shares for it.

        // Impact
        // This affects fee Accrual since it is based on lastTotalAssets

        Tester.submitCap(1, 3);
        _delay(322374);
        _delay(285249);
        Tester.acceptCap(3);
        Tester.setSupplyQueue(11);
        console.log("vault.totalAssets(): ", vault.totalAssets());
        console.log("vault.totalSupply(): ", vault.totalSupply());
        console.log("vault.lastTotalAssets(): ", vault.lastTotalAssets());
        _logSeparatorInternal();

        Tester.depositVault(1, 0);
        console.log("vault.totalAssets(): ", vault.totalAssets());
        console.log("vault.totalSupply(): ", vault.totalSupply());
        console.log("vault.lastTotalAssets(): ", vault.lastTotalAssets());
        _logSeparatorInternal();

        Tester.donateUnderlyingToSilo(2, 3);
        console.log("vault.totalAssets(): ", vault.totalAssets());
        console.log("vault.totalSupply(): ", vault.totalSupply());
        console.log("vault.lastTotalAssets(): ", vault.lastTotalAssets());
        _logSeparatorInternal();

        Tester.withdrawVault(1, 0);
        console.log("vault.totalAssets(): ", vault.totalAssets());
        console.log("vault.totalSupply(): ", vault.totalSupply());
        console.log("vault.lastTotalAssets(): ", vault.lastTotalAssets());
    }

    function test_replay_3depositVault() public {
        // @audit-ok
        // Inconsistency in asset tracking after deposits
        //
        // Before calling depositVault:
        //      - vault.totalAssets(): 0
        //      - vault.totalSupply(): 0
        //      - vault.lastTotalAssets(): 0
        //
        // After calling depositVault with 3 assets:
        //      - vault.totalAssets(): 2
        //      - vault.totalSupply(): 3
        //      - vault.lastTotalAssets(): 3
        //
        //
        // Summary:
        // The protocol fails to correctly account with assets deposited on the underlying vaults.
        // Although there are 3 assets deposited, only 2 are reported back,
        //
        // Issue:
        // Violates GPOST_ACCOUNTING_D:
        //      - Expected: lastTotalAssets() == totalAssets() after any transaction.
        //      - Actual: lastTotalAssets() still tracks the lost wei, while totalAssets()
        //        no longer includes it since the SiloVault holds no shares for it.
        Tester.submitCap(18, 3);
        _delay(318197);
        _delay(291190);
        Tester.submitCap(1, 0);
        Tester.acceptCap(3);
        _delay(626639);
        Tester.acceptCap(0);
        Tester.setSupplyQueue(7);

        Tester.donateUnderlyingToSilo(1, 3);
        console.log("vault.totalAssets(): ", vault.totalAssets());
        console.log("vault.totalSupply(): ", vault.totalSupply());
        console.log("vault.lastTotalAssets(): ", vault.lastTotalAssets());
        _logSeparatorInternal();

        Tester.depositVault(3, 0);
        console.log("vault.totalAssets(): ", vault.totalAssets());
        console.log("vault.totalSupply(): ", vault.totalSupply());
        console.log("vault.lastTotalAssets(): ", vault.lastTotalAssets());
        _logSeparatorInternal();
    }

    function test_replay_assert_ERC4626_DEPOSIT_INVARIANT_C() public {
        // @audit-ok `if (_shares == 0) revert ErrorsLib.InputZeroShares();` make 0 deposit revert which breaks the ERC4626 rule
        /// @dev added maxDeposit != 0 check -> consider documenting this difference in the ERC4626 spec
        Tester.assert_ERC4626_DEPOSIT_INVARIANT_C();
    }

    function test_replay_assert_ERC4626_MINT_INVARIANT_C() public {
        // @audit-ok `if (_shares == 0) revert ErrorsLib.InputZeroShares();` make 0 deposit revert which breaks the ERC4626 rule
        /// @dev added maxDeposit != 0 check -> consider documenting this difference in the ERC4626 spec
        Tester.assert_ERC4626_MINT_INVARIANT_C();
    }

    function test_replay_2mintVault() public {
        // @audit-ok if underlying vault is open to donations, like in this case IdleVault, the protocol leaks assets since it deposits without receiving shares
        // Same case than test_replay_2depositVault
        Tester.submitCap(1, 3);
        _delay(626050);
        Tester.donateUnderlyingToSilo(1, 3);
        Tester.acceptCap(3);
        Tester.setSupplyQueue(11);
        Tester.assert_ERC4626_DEPOSIT_INVARIANT_C();
        Tester.mintVault(1, 0);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                     INVARIANTS REPLAY                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function test_replay_echidna_INV_MARKETS() public {
        Tester.submitCap(1, 0);
        echidna_INV_MARKETS();
    }
}
