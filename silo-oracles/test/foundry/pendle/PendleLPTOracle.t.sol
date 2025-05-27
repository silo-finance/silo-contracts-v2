// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {PendleLPTOracle} from "silo-oracles/contracts/pendle/PendleLPTOracle.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {PendleLPTToSyOracleFactory} from "silo-oracles/contracts/pendle/PendleLPTToSyOracleFactory.sol";
import {PendleLPTToAssetOracleFactory} from "silo-oracles/contracts/pendle/PendleLPTToAssetOracleFactory.sol";
import {PendleLPTToSyOracleDeploy} from "silo-oracles/deploy/pendle/PendleLPTToSyOracleDeploy.s.sol";
import {PendleLPTToAssetOracleDeploy} from "silo-oracles/deploy/pendle/PendleLPTToAssetOracleDeploy.s.sol";
import {PendleLPTToSyOracleFactoryDeploy} from "silo-oracles/deploy/pendle/PendleLPTToSyOracleFactoryDeploy.s.sol";
import {
    PendleLPTToAssetOracleFactoryDeploy
} from "silo-oracles/deploy/pendle/PendleLPTToAssetOracleFactoryDeploy.s.sol";

/*
    FOUNDRY_PROFILE=oracles forge test --mc PendleLPTOracleTest --ffi -vv
*/
contract PendleLPTOracleTest is Test {
    PendleLPTToSyOracleFactory factoryToSy;
    PendleLPTToAssetOracleFactory factoryToAsset;
    PendleLPTOracle oracleSy;
    PendleLPTOracle oracleAsset;

    event PendleLPTOracleCreated(ISiloOracle indexed pendleLPTOracle);

    function setUp() public {
        vm.createSelectFork(vm.envString("RPC_SONIC"), 29883290); // forking block may 27 2025

        PendleLPTToSyOracleFactoryDeploy factorySyDeploy = new PendleLPTToSyOracleFactoryDeploy();
        factorySyDeploy.disableDeploymentsSync();
        factoryToSy = PendleLPTToSyOracleFactory(factorySyDeploy.run());

        PendleLPTToAssetOracleFactoryDeploy factoryAssetDeploy = new PendleLPTToAssetOracleFactoryDeploy();
        factoryToAsset = PendleLPTToAssetOracleFactory(factoryAssetDeploy.run());
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_LPTToAssetOracle_getPrice --ffi -vv
     */
    function test_LPTToAssetOracle_getPrice() public {
        ISiloOracle underlyingOracle = ISiloOracle(0x8c5bb146f416De3fbcD8168cC844aCf4Aa2098c5); // USDC/USD
        address market = 0x3F5EA53d1160177445B1898afbB16da111182418; // AUSDC (14 Aug 2025)

        PendleLPTToAssetOracleDeploy oracleAssetDeploy = new PendleLPTToAssetOracleDeploy();
        oracleAssetDeploy.setParams(market, underlyingOracle);

        oracleAsset = PendleLPTOracle(address(oracleAssetDeploy.run()));

        uint256 price = oracleAsset.quote(1e18, market);
        assertEq(price, 2049835019614218201342436720000);
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_LPTToSyOracle_getPrice --ffi -vv
     */
    function test_LPTToSyOracle_getPrice() public {
        ISiloOracle underlyingOracle = ISiloOracle(0x689783B8A4D8288fBacbeDCCA43e5b9B2A7ab174); // chainlink woS wS
        address market = 0x4E82347Bc41CFD5d62cEF483C7f0a739a8158963; // WOS (may 29 2025)

        PendleLPTToSyOracleDeploy oracleSyDeploy = new PendleLPTToSyOracleDeploy();
        oracleSyDeploy.setParams(market, underlyingOracle);

        oracleSy = PendleLPTOracle(address(oracleSyDeploy.run()));

        uint256 price = oracleSy.quote(1e18, market);
        assertEq(price, 2260752160791343792);
    }
}
