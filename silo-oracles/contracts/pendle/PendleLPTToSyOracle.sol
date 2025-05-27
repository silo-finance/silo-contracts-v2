// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {PendleLPTOracle} from "./PendleLPTOracle.sol";

/// @notice PendleLPTOracle is an oracle, which multiplies the underlying LP token price by getLpToSyRate from Pendle.
/// This oracle must be deployed using PendleLPTOracleFactory contract. PendleLPTOracle decimals are equal to underlying
/// oracle's decimals. TWAP duration is constant and equal to 30 minutes. UNDERLYING_ORACLE must return the price of 
/// LP token's underlying asset. Quote token of PendleLPTOracle is equal to UNDERLYING_ORACLE quote token.
contract PendleLPTToSyOracle is PendleLPTOracle {
    constructor(ISiloOracle _underlyingOracle, address _market) PendleLPTOracle(_underlyingOracle, _market) {}

    function _getRate() internal view override returns (uint256) {
        return PENDLE_ORACLE.getLpToSyRate(MARKET, TWAP_DURATION);
    }
}