// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {TestERC20} from "silo-core/test/invariants/utils/mocks/TestERC20.sol";
import {PendleLPTOracle} from "silo-oracles/contracts/pendle/PendleLPTOracle.sol";
import {IPendleLPTToSyOracleFactory} from "silo-oracles/contracts/interfaces/IPendleLPTToSyOracleFactory.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {PendleLPTToSyOracleFactory} from "silo-oracles/contracts/pendle/PendleLPTToSyOracleFactory.sol";
import {PendleLPTToAssetOracleFactory} from "silo-oracles/contracts/pendle/PendleLPTToAssetOracleFactory.sol";
import {PendleLPTOracle} from "silo-oracles/contracts/pendle/PendleLPTOracle.sol";
import {PendleLPTToSyOracleDeploy} from "silo-oracles/deploy/pendle/PendleLPTToSyOracleDeploy.s.sol";
import {PendleLPTToSyOracleFactoryDeploy} from "silo-oracles/deploy/pendle/PendleLPTToSyOracleFactoryDeploy.s.sol";
import {
    PendleLPTToAssetOracleFactoryDeploy
} from "silo-oracles/deploy/pendle/PendleLPTToAssetOracleFactoryDeploy.s.sol";
import {Forking} from "silo-oracles/test/foundry/_common/Forking.sol";
import {IPyYtLpOracleLike} from "silo-oracles/contracts/pendle/interfaces/IPyYtLpOracleLike.sol";
import {SiloOracleMock1} from "silo-oracles/test/foundry/_mocks/silo-oracles/SiloOracleMock1.sol";

/*
    FOUNDRY_PROFILE=oracles forge test -vv --match-contract PendleLPTOracleTest --ffi
*/
contract PendleLPTOracleTest is Test {
    PendleLPTToSyOracleFactory factoryToSy;
    PendleLPTToAssetOracleFactory factoryToAsset;
    PendleLPTOracle oracle;
    IPyYtLpOracleLike pendleOracle = IPyYtLpOracleLike(0x9a9Fa8338dd5E5B2188006f1Cd2Ef26d921650C2);
    ISiloOracle underlyingOracle;

    address market = 0xC1fd739f2Bf1Aad96F04d6AE35ED04DA4D68366b; // WOS
    address ptUnderlyingToken = 0x689783B8A4D8288fBacbeDCCA43e5b9B2A7ab174; // chainlink woS wS

    event PendleLPTOracleCreated(ISiloOracle indexed pendleLPTOracle);

    function setUp() public {
        vm.createSelectFork(vm.envString("RPC_SONIC"), 29883290);

        PendleLPTToSyOracleFactoryDeploy factorySyDeploy = new PendleLPTToSyOracleFactoryDeploy();
        factorySyDeploy.disableDeploymentsSync();
        factoryToSy = PendleLPTToSyOracleFactory(factorySyDeploy.run());

        PendleLPTToAssetOracleFactoryDeploy factoryAssetDeploy = new PendleLPTToAssetOracleFactoryDeploy();
        factoryToAsset = PendleLPTToAssetOracleFactory(factoryAssetDeploy.run());

        PendleLPTToSyOracleDeploy oracleSyDeploy = new PendleLPTToSyOracleDeploy();
        oracleSyDeploy.setParams(market, underlyingOracle);

        // oracle = PendleLPTOracle(address(oracleDeploy.run())); // TODO: increase cardinality
    }

    function test_getPrice() public {

    }
}
