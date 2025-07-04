// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {PendleLPTToSyOracle} from "../PendleLPTToSyOracle.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {IPendleLPWrapperLike} from "silo-oracles/contracts/pendle/interfaces/IPendleLPWrapperLike.sol";

/// @notice Price provider for the wrapped Pendle LP tokens.
/// @dev Wrapped tokens are priced 1:1 with Pendle LP tokens.
contract PendleWrapperLPTToSyOracle is PendleLPTToSyOracle {
    IPendleLPWrapperLike public immutable LPT_WRAPPER;

    constructor(
        ISiloOracle _underlyingOracle,
        IPendleLPWrapperLike _lptWrapper
    ) PendleLPTToSyOracle(_underlyingOracle, _lptWrapper.LP()) {
        LPT_WRAPPER = _lptWrapper;
    }

    function _getBaseToken() internal view override returns (address baseToken) {
        baseToken = address(LPT_WRAPPER);
    }
}
