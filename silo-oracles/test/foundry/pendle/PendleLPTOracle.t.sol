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
import {PendleLPTToAssetOracleDeploy} from "silo-oracles/deploy/pendle/PendleLPTToAssetOracleDeploy.s.sol";
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
    PendleLPTOracle oracleSy;
    PendleLPTOracle oracleAsset;
    address underlyingToken; // USDC/USD

    event PendleLPTOracleCreated(ISiloOracle indexed pendleLPTOracle);

    function setUp() public {
        vm.createSelectFork(vm.envString("RPC_SONIC"), 29883290);

        PendleLPTToSyOracleFactoryDeploy factorySyDeploy = new PendleLPTToSyOracleFactoryDeploy();
        factorySyDeploy.disableDeploymentsSync();
        factoryToSy = PendleLPTToSyOracleFactory(factorySyDeploy.run());

        PendleLPTToAssetOracleFactoryDeploy factoryAssetDeploy = new PendleLPTToAssetOracleFactoryDeploy();
        factoryToAsset = PendleLPTToAssetOracleFactory(factoryAssetDeploy.run());

        // PendleLPTToSyOracleDeploy oracleSyDeploy = new PendleLPTToSyOracleDeploy();
        // oracleSyDeploy.setParams(market, underlyingOracle);

        // oracle = PendleLPTOracle(address(oracleSyDeploy.run()));
    }

    function test_LPTToAssetOracle_getPrice() public {
        IPyYtLpOracleLike pendleOracle = IPyYtLpOracleLike(0x9a9Fa8338dd5E5B2188006f1Cd2Ef26d921650C2);
        ISiloOracle underlyingOracle = ISiloOracle(0x8c5bb146f416De3fbcD8168cC844aCf4Aa2098c5);

        address market = 0x3F5EA53d1160177445B1898afbB16da111182418; // AUSDC

        PendleLPTToAssetOracleDeploy oracleAssetDeploy = new PendleLPTToAssetOracleDeploy();
        oracleAssetDeploy.setParams(market, underlyingOracle);

        oracleAsset = PendleLPTOracle(address(oracleAssetDeploy.run()));

        // 2049835019614218201342436720000

        uint256 price = oracleAsset.quote(1e6, market);
        emit log_named_uint("price", price);
        emit log_named_uint("price", price / 1e18);
    }
}
