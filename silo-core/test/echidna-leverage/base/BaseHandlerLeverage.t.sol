// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {BaseHandler} from "silo-core/test/invariants/base/BaseHandler.t.sol";

/// @title BaseHandler
/// @notice Contains common logic for all handlers
/// @dev inherits all suite assertions since per action assertions are implmenteds in the handlers
contract BaseHandlerLeverage is BaseHandler {
    function _getOtherSilo(address _silo) internal view returns (address otherSilo) {
        (address silo0, address silo1) = ISilo(_silo).config().getSilos();
        otherSilo = silo0 == _silo ? silo1 : silo0;
    }
}
