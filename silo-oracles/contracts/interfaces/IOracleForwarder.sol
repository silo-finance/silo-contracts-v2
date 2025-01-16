
// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

/// @notice Forward all calls to the oracle
interface IOracleForwarder is ISiloOracle{
    event OracleSet(ISiloOracle indexed oracle);

    error QuoteTokenMustBeTheSame();

    /// @notice Set the oracle to be used by the forwarder
    /// @param _oracle The oracle to be used by the forwarder
    function setOracle(ISiloOracle _oracle) external;

    /// @notice Get the oracle used by the forwarder
    /// @return The oracle used by the forwarder
    function oracle() external view returns (ISiloOracle);
}
