// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC4626, IERC20} from "openzeppelin5/interfaces/IERC4626.sol";

// Invariant Contracts
import {BaseInvariants} from "./invariants/BaseInvariants.t.sol";
import {ERC4626Invariants} from "./invariants/ERC4626Invariants.t.sol";

/// @title Invariants
/// @notice Wrappers for the protocol invariants implemented in each invariants contract
/// @dev recognised by Echidna when property mode is activated
/// @dev Inherits BaseInvariants
abstract contract Invariants is BaseInvariants, ERC4626Invariants {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                     BASE INVARIANTS                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function echidna_INV_BASE() public returns (bool) {
        for (uint256 i; i < markets.length; i++) {
            assert_INV_BASE_A(markets[i]);
            assert_INV_BASE_C(markets[i]);
            assert_INV_BASE_D(markets[i]);
            assert_INV_BASE_E(markets[i]);
        }

        assert_INV_BASE_F();

        return true;
    }

    function echidna_INV_QUEUES() public returns (bool) {
        assert_INV_QUEUES_AE();
        assert_INV_QUEUES_B();

        return true;
    }

    function echidna_INV_TIMELOCK() public returns (bool) {
        assert_INV_TIMELOCK_A();
        assert_INV_TIMELOCK_D();
        assert_INV_TIMELOCK_E();
        assert_INV_TIMELOCK_F();

        return true;
    }

    function echidna_INV_MARKETS() public returns (bool) {
        for (uint256 i; i < markets.length; i++) {
            assert_INV_MARKETS_AB(markets[i]);
        }

        return true;
    }

    function echidna_INV_FEES() public returns (bool) {
        assert_INV_FEES_A();

        return true;
    }

    function echidna_INV_ACCOUNTING() public returns (bool) {
        //assert_INV_ACCOUNTING_A();
        assert_INV_ACCOUNTING_C();

        return true;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                    ERC4626 INVARIANTS                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function echidna_ERC4626_ASSETS_INVARIANTS() public returns (bool) {
        assert_ERC4626_ASSETS_INVARIANT_A();
        assert_ERC4626_ASSETS_INVARIANT_B();
        assert_ERC4626_ASSETS_INVARIANT_C();
        assert_ERC4626_ASSETS_INVARIANT_D();

        return true;
    }

    function echidna_ERC4626_USERS() public returns (bool) {
        for (uint256 i; i < actorAddresses.length; i++) {
            assert_ERC4626_DEPOSIT_INVARIANT_A(actorAddresses[i]);
            assert_ERC4626_MINT_INVARIANT_A(actorAddresses[i]);
            assert_ERC4626_WITHDRAW_INVARIANT_A(actorAddresses[i]);
            assert_ERC4626_REDEEM_INVARIANT_A(actorAddresses[i]);
        }

        return true;
    }
}
