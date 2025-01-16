// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {OracleForwarder} from "silo-oracles/contracts/forwarder/OracleForwarder.sol";
import {IOracleForwarderFactory} from "silo-oracles/contracts/interfaces/IOracleForwarderFactory.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {IOracleForwarder} from "silo-oracles/contracts/interfaces/IOracleForwarder.sol";

contract OracleForwarderFactory is IOracleForwarderFactory {
    mapping(address => bool) public createdInFactory;

    /// @inheritdoc IOracleForwarderFactory
    function createOracleForwarder(
        ISiloOracle _oracle,
        address _owner
    ) external returns (IOracleForwarder oracleForwarder) {
        oracleForwarder = IOracleForwarder(address(new OracleForwarder(_oracle, _owner)));

        createdInFactory[address(oracleForwarder)] = true;

        emit OracleForwarderCreated(address(oracleForwarder));
    }
}
