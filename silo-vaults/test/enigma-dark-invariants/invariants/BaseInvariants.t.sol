// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries

// Interfaces
import {IERC4626, IERC20} from "openzeppelin5/interfaces/IERC4626.sol";
import {MarketConfig, PendingUint192} from "silo-vaults/contracts/interfaces/ISiloVault.sol";

// Contracts
import {HandlerAggregator} from "../HandlerAggregator.t.sol";

import "forge-std/console.sol";

/// @title BaseInvariants
/// @notice Implements Invariants for the protocol
/// @dev Inherits HandlerAggregator to check actions in assertion testing mode
abstract contract BaseInvariants is HandlerAggregator {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          BASE                                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_INV_BASE_A(IERC4626 market) internal {
        MarketConfig memory config = vault.config(market);
        if (config.cap > 0) assertTrue(config.enabled, INV_BASE_A);
    }

    function assert_INV_BASE_C(IERC4626 market) internal {
        MarketConfig memory config = vault.config(market);
        if (config.cap > 0) assertEq(config.removableAt, 0, INV_BASE_C);
    }

    function assert_INV_BASE_D(IERC4626 market) internal {
        MarketConfig memory config = vault.config(market);
        if (!config.enabled) assertEq(config.removableAt, 0, INV_BASE_D);
    }

    function assert_INV_BASE_E(IERC4626 market) internal {
        PendingUint192 memory pendingCap = vault.pendingCap(market);
        if (pendingCap.value != 0 || pendingCap.validAt != 0) {
            assertEq(vault.config(market).removableAt, 0, INV_BASE_E);
        }
    }

    function assert_INV_BASE_F() internal {
        assertLe(vault.fee(), MAX_FEE, INV_BASE_F);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         QUEUES                                            //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    mapping(IERC4626 => bool) withdrawQueueCache;

    function assert_INV_QUEUES_AE() internal {
        uint256 len = vault.withdrawQueueLength();

        for (uint256 i; i < len; i++) {
            IERC4626 market = vault.withdrawQueue(i);
            assertFalse(withdrawQueueCache[market], INV_QUEUES_A);

            withdrawQueueCache[market] = true;
        }

        for (uint256 i; i < markets.length; i++) {
            if (vault.config(markets[i]).enabled) {
                assertTrue(withdrawQueueCache[markets[i]], INV_QUEUES_E);
            }
        }

        for (uint256 i; i < markets.length; i++) {
            delete withdrawQueueCache[markets[i]];
        }
    }

    function assert_INV_QUEUES_B() internal {
        uint256 len = vault.withdrawQueueLength();

        for (uint256 i; i < len; i++) {
            assertTrue(vault.config(vault.withdrawQueue(i)).enabled, INV_QUEUES_B);
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                        TIMELOCK                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_INV_TIMELOCK_A() internal {
        assertLt(vault.pendingTimelock().value, vault.timelock(), INV_TIMELOCK_A);
    }

    function assert_INV_TIMELOCK_D() internal {
        address pendingGuardian = vault.pendingGuardian().value;

        if (pendingGuardian != address(0)) {
            assertTrue(pendingGuardian != vault.guardian(), INV_TIMELOCK_D);
        }
    }

    function assert_INV_TIMELOCK_E() internal {
        uint256 pendingTimelock = vault.pendingTimelock().value;
        if (pendingTimelock != 0) {
            assertLt(pendingTimelock, MAX_TIMELOCK, INV_TIMELOCK_E);
            assertGt(pendingTimelock, MIN_TIMELOCK, INV_TIMELOCK_E);
        }
    }

    function assert_INV_TIMELOCK_F() internal {
        uint256 timelock = vault.timelock();
        assertLt(timelock, MAX_TIMELOCK, INV_TIMELOCK_F);
        assertGt(timelock, MIN_TIMELOCK, INV_TIMELOCK_F);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                        MARKETS                                            //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_INV_MARKETS_AB(IERC4626 market) internal {
        uint256 pendingCap = vault.pendingCap(market).value;
        uint256 cap = vault.config(market).cap;
        uint256 validAt = vault.pendingCap(market).validAt;

        if (pendingCap == 0) {
            assertEq(pendingCap, validAt, INV_MARKETS_A);
        } else {
            assertGt(pendingCap, cap, INV_MARKETS_B);
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          FEES                                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_INV_FEES_A() internal {
        uint256 fee = vault.fee();
        address feeRecipient = vault.feeRecipient();

        assertEq(fee == 0, feeRecipient == address(0), INV_FEES_A);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         ACCOUNTING                                        //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_INV_ACCOUNTING_A() internal {
        assertGe(vault.totalAssets(), vault.lastTotalAssets(), INV_ACCOUNTING_A);
    }

    function assert_INV_ACCOUNTING_C() internal {
        assertEq(asset.balanceOf(address(vault)), underlyingAmountDonatedToVault, INV_ACCOUNTING_C);
    }
}
