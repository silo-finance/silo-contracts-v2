// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";
import {ILiquidityGaugeFactory} from "ve-silo/contracts/gauges/interfaces/ILiquidityGaugeFactory.sol";
import {LiquidityGaugesDeployments} from "./LiquidityGaugesDeployments.sol";
import {GaugeDeployScript} from "../GaugeDeployScript.sol";
import {LiquidityGaugeConfigsParser} from "./LiquidityGaugeConfigsParser.sol";

/**
Supported tokens: protectedShareToken | collateralShareToken | debtShareToken
Silo deployments: silo-core/deploy/silo/_siloDeployments.json
MAX_RELATIVE_WEIGHT_CAP = 10 ** 18

FOUNDRY_PROFILE=ve-silo-test CONFIG=EXAMPLE_TEST \
    forge script ve-silo/deploy/gauges/liquidity-gauge/LiquidityGaugeDeployer.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract LiquidityGaugeDeployer is GaugeDeployScript {
    struct LiquidityGaugeDeploymentConfig {
        string silo;
        string asset;
        string token;
        uint256 relativeWeightCap;
    }

    function run() public returns (address gauge) {
        string memory chainAlias = ChainsLib.chainAlias();
        string memory cofigName = vm.envString("CONFIG");

        LiquidityGaugeDeploymentConfig memory config = LiquidityGaugeConfigsParser.getConfig(
            chainAlias,
            cofigName
        );

        address hookReceiver = _resolveSiloHookReceiver(config.silo, config.asset, config.token);

        ILiquidityGaugeFactory factory = ILiquidityGaugeFactory(
            VeSiloDeployments.get(
                VeSiloContracts.LIQUIDITY_GAUGE_FACTORY,
                chainAlias
            )
        );

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);
        gauge = factory.create(config.relativeWeightCap, hookReceiver);
        vm.stopBroadcast();

        LiquidityGaugesDeployments.save(chainAlias, cofigName, gauge);
    }
}
