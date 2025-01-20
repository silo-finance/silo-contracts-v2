
// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {IOracleForwarder} from "silo-oracles/contracts/interfaces/IOracleForwarder.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

interface IOracleForwarderFactory {
    event OracleForwarderCreated(address indexed oracleForwarder);

    /// @notice Create a new oracle forwarder
    /// @param _oracle The oracle to be used by the forwarder
    /// @param _owner The owner of the forwarder
    /// @return oracleForwarder The oracle forwarder created
    function createOracleForwarder(
        ISiloOracle _oracle,
        address _owner
    ) external returns (IOracleForwarder oracleForwarder);
}
