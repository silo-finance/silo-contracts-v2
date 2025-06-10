// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {IPendleOracleHelper} from "silo-oracles/contracts/pendle/interfaces/IPendleOracleHelper.sol";
import {PendleLPTOracle} from "silo-oracles/contracts/pendle/lp-tokens/PendleLPTOracle.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

import {PendleWrapperLPTToSyOracle} from "silo-oracles/contracts/pendle/lp-tokens/wrappers/PendleWrapperLPTToSyOracle.sol";
import {PendleWrapperLPTToAssetOracle} from "silo-oracles/contracts/pendle/lp-tokens/wrappers/PendleWrapperLPTToAssetOracle.sol";

import {
    PendleWrapperLPTToSyOracleFactory
} from "silo-oracles/contracts/pendle/lp-tokens/wrappers/PendleWrapperLPTToSyOracleFactory.sol";

import {
    PendleWrapperLPTToAssetOracleFactory
} from "silo-oracles/contracts/pendle/lp-tokens/wrappers/PendleWrapperLPTToAssetOracleFactory.sol";

import {
    PendleWrapperLPTToSyOracleFactoryDeploy
} from "silo-oracles/deploy/pendle/PendleWrapperLPTToSyOracleFactoryDeploy.s.sol";

import {
    PendleWrapperLPTToAssetOracleFactoryDeploy
} from "silo-oracles/deploy/pendle/PendleWrapperLPTToAssetOracleFactoryDeploy.s.sol";

/*
    FOUNDRY_PROFILE=oracles forge test --mc PendleWrapperLPTOracle --ffi -vv
*/
contract PendleWrapperLPTOracle is Test {
    uint32 public constant TWAP_DURATION = 30 minutes;
    IPendleOracleHelper public constant PENDLE_ORACLE =
        IPendleOracleHelper(0x9a9Fa8338dd5E5B2188006f1Cd2Ef26d921650C2);

    PendleWrapperLPTToSyOracleFactory factoryToSy;
    PendleWrapperLPTToAssetOracleFactory factoryToAsset;
    PendleLPTOracle oracleSy;
    PendleLPTOracle oracleAsset;

    event PendleLPTOracleCreated(ISiloOracle indexed pendleLPTOracle);

    function setUp() public {
        vm.createSelectFork(vm.envString("RPC_MAINNET"), 22672300); // forking block jun 10 2025

        PendleWrapperLPTToSyOracleFactoryDeploy factorySyDeploy = new PendleWrapperLPTToSyOracleFactoryDeploy();
        factorySyDeploy.disableDeploymentsSync();
        factoryToSy = PendleWrapperLPTToSyOracleFactory(factorySyDeploy.run());

        PendleWrapperLPTToAssetOracleFactoryDeploy factoryAssetDeploy = new PendleWrapperLPTToAssetOracleFactoryDeploy();
        factoryToAsset = PendleWrapperLPTToAssetOracleFactory(factoryAssetDeploy.run());
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_wrapperLPTToAssetOracle_deploy --ffi -vv
     */
    function test_wrapperLPTToAssetOracle_deploy() public {
    }
}
