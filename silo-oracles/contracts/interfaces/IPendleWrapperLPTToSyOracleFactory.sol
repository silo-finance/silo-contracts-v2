// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {IPendleLPWrapperLike} from "silo-oracles/contracts/pendle/interfaces/IPendleLPWrapperLike.sol";

/// @notice Factory for creating PendleWrapperLPTToSyOracle instances.
interface IPendleWrapperLPTToSyOracleFactory {
    event PendleWrapperLPTToSyOracleCreated(ISiloOracle indexed pendleWrapperLPTToSyOracle);

    /// @notice Create a new PendleLPTToSyOracle
    /// @param _underlyingOracle Oracle for LP token's underlying asset.
    /// @param _wrapper Wrapped Pendle LP token's address.
    /// @param _externalSalt The external salt to be used together with factory salt
    /// @return pendleWrapperLPTToSyOracle The pendleWrapperLPTToSyOracle created.
    function create(
        ISiloOracle _underlyingOracle,
        IPendleLPWrapperLike _wrapper,
        bytes32 _externalSalt
    ) external returns (ISiloOracle pendleWrapperLPTToSyOracle);
}
