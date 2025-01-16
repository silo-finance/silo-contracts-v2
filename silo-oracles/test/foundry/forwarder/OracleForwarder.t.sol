// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {OracleForwarderFactoryDeploy} from "silo-oracles/deploy/OracleForwarderFactoryDeploy.sol";
import {OracleForwarderFactory} from "silo-oracles/contracts/forwarder/OracleForwarderFactory.sol";
import {IOracleForwarderFactory} from "silo-oracles/contracts/interfaces/IOracleForwarderFactory.sol";
import {IOracleForwarder} from "silo-oracles/contracts/interfaces/IOracleForwarder.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

import {SiloOracleMock1} from "silo-oracles/test/foundry/_mocks/silo-oracles/SiloOracleMock1.sol";
import {SiloOracleMock2} from "silo-oracles/test/foundry/_mocks/silo-oracles/SiloOracleMock2.sol";

contract OracleForwarderTest is Test {
    address internal _owner = makeAddr("Owner");

    SiloOracleMock1 internal _oracleMock1;
    SiloOracleMock2 internal _oracleMock2;

    IOracleForwarder internal _oracleForwarder;

    function setUp() public {
        _oracleMock1 = new SiloOracleMock1();
        _oracleMock2 = new SiloOracleMock2();

        OracleForwarderFactoryDeploy factoryDeploy = new OracleForwarderFactoryDeploy();
        factoryDeploy.disableDeploymentsSync();

        address factory = factoryDeploy.run();

        _oracleForwarder = IOracleForwarderFactory(factory).createOracleForwarder(
            ISiloOracle(address(_oracleMock1)),
            _owner
        );
    }

    // FOUNDRY_PROFILE=oracles forge test --mt test_OracleForwarder_setOracle
    function test_OracleForwarder_setOracle() public {
        _oracleForwarder.setOracle(ISiloOracle(address(_oracleMock2)));
        // assertEq(_oracleForwarder.oracle(), ISiloOracle(address(_oracleMock2)));
    }
}
