// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// Invariant Contracts
import {BaseInvariants} from "./invariants/BaseInvariants.t.sol";

import "forge-std/console.sol";

/// @title Invariants
/// @notice Wrappers for the protocol invariants implemented in each invariants contract
/// @dev recognised by Echidna when property mode is activated
/// @dev Inherits BaseInvariants
abstract contract Invariants is BaseInvariants {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                     BASE INVARIANTS                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function echidna_BASE_INVARIANT() public returns (bool) {
//        for (uint256 i = 0; i < silos.length; i++) {
//            assert_BASE_INVARIANT_B(silos[i], debtTokens[i]);
//            assert_BASE_INVARIANT_C(silos[i]);
//            assert_BASE_INVARIANT_E(silos[i], siloToken);
//            assert_BASE_INVARIANT_F(silos[i], siloToken);
//            assert_BASE_INVARIANT_H();
//            assert_BASE_INVARIANT_J(silos[i]);
//            for (uint256 j = 0; j < actorAddresses.length; j++) {
//                address collateralSilo = siloConfig.borrowerCollateralSilo(actorAddresses[j]);
//
//                if (collateralSilo != address(0)) {
//                    (address protectedShareToken,,) = siloConfig.getShareTokens(collateralSilo);
//
//                    assert_BASE_INVARIANT_D(
//                        silos[i], debtTokens[i], collateralSilo, protectedShareToken, actorAddresses[j]
//                    );
//                }
//            }
//        }
        return true;
    }

    function echidna_SILO_INVARIANT() public returns (bool) {
//        for (uint256 i = 0; i < silos.length; i++) {
//            assert_SILO_INVARIANT_A(silos[i]);
//        }
//        for (uint256 j = 0; j < actorAddresses.length; j++) {
//            assert_SILO_INVARIANT_D(actorAddresses[j]);
//            assert_SILO_INVARIANT_E(actorAddresses[j]);
//            assert_SILO_INVARIANT_F(actorAddresses[j]);
//        }
        return true;
    }
}
