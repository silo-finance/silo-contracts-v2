// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AccessControl} from "openzeppelin5/access/AccessControl.sol";
import {Pausable} from "openzeppelin5/utils/Pausable.sol";

/// @title Pausable contract with a separate role for pausing
abstract contract PausableWithAccessControl is AccessControl, Pausable {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
}
