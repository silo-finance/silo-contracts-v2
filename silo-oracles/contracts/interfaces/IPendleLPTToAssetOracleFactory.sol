// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

interface IPendleLPTToAssetOracleFactory {
    event PendleLPTToAssetOracleCreated(ISiloOracle indexed pendleLPTToAssetOracle);

    /// @notice Create a new PendleLPTToAssetOracle
    /// @param _underlyingOracle Oracle for LP token's underlying asset.
    /// @param _market Pendle market's address.
    /// @param _externalSalt The external salt to be used together with factory salt
    /// @return pendleLPTOracle The pendleLPTOracle created.
    function create(
        ISiloOracle _underlyingOracle,
        address _market,
        bytes32 _externalSalt
    ) external returns (ISiloOracle pendleLPTOracle);
}
