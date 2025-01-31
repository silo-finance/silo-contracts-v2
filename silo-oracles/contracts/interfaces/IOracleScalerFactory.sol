// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

interface IOracleScalerFactory {
    event OracleScalerCreated(ISiloOracle indexed oracleScaler);

    /// @notice Create a new oracle scaler
    /// @param _quoteToken The quote token for this oracle to support.
    /// @return oracleScaler The oracle scaler created
    function createOracleScaler(
        address _quoteToken
    ) external returns (ISiloOracle oracleScaler);
}
