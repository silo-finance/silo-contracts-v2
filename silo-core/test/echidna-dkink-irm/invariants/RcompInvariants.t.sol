// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {DynamicKinkModelHandlers} from "silo-core/test/echidna-dkink-irm/DynamicKinkModelHandlers.t.sol";

/// @title RcompInvariants
/// @notice Implements specific invariants for the DynamicKinkModel Interest Rate Model
abstract contract RcompInvariants is DynamicKinkModelHandlers {
    /// @dev Compound interest rate must be within valid bounds
    function echidna_rcomp_bounds() public view returns (bool) {
        return _stateAfter.rcomp >= 0 && _stateAfter.rcomp <= _RCOMP_CAP;
    }
}
