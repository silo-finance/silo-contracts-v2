// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {RcurInvariants} from "silo-core/test/echidna-dkink-irm/invariants/RcurInvariants.t.sol";
import {RcompInvariants} from "silo-core/test/echidna-dkink-irm/invariants/RcompInvariants.t.sol";
import {UtilizationInvariants} from "silo-core/test/echidna-dkink-irm/invariants/UtilizationInvariants.t.sol";
import {IDynamicKinkModel} from "silo-core/contracts/interfaces/IDynamicKinkModel.sol";

/// @title Invariants
/// @notice Main invariant wrapper contract that combines all components
/// @dev This is the entry point for Echidna testing
contract Invariants is RcurInvariants, RcompInvariants, UtilizationInvariants {
    /// @dev Test that the setup is initialized correctly
    function echidna_test_initialized_setup() public view returns (bool) {
        if (_stateBefore.initialized) {
            // We can't transition from initialized to non-initialized
            return _stateAfter.initialized;
        }

        return true;
    }

    /// @notice All coefficients are non-negative
    /// @dev Invariants:
    /// c1, c2, c+, c− ≥ 0
    /// dmax ≥ c2
    /// 0 ≤ kmin ≤ kmax
    function echidna_coefficient_non_negative() public view returns (bool) {
        IDynamicKinkModel.Config memory config = _stateAfter.config;

        return config.c1 >= 0 
            && config.c2 >= 0 
            && config.cplus >= 0 
            && config.cminus >= 0 
            && config.dmax >= config.c2 && config.kmin >= 0 && config.kmin <= config.kmax;
    }
}
