// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";
import {IChildChainGaugeFactory} from "ve-silo/contracts/gauges/interfaces/IChildChainGaugeFactory.sol";
import {ChildChainGaugesDeployments} from "./ChildChainGaugesDeployments.sol";
import {GaugeDeployScript} from "../GaugeDeployScript.sol";
import {ChildChainGaugeConfigsParser} from "./ChildChainGaugeConfigsParser.sol";

/**
Supported tokens: protectedShareToken | collateralShareToken | debtShareToken
Silo deployments: silo-core/deploy/silo/_siloDeployments.json

FOUNDRY_PROFILE=ve-silo-test CONFIG=EXAMPLE_TEST \
    forge script ve-silo/deploy/gauges/child-chain-gauge/ChildChainGaugeDeployer.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract ChildChainGaugeDeployer is GaugeDeployScript {
    struct ChildChainGaugeDeploymentConfig {
        string silo;
        string asset;
        string token;
    }

    function run() public returns (address gauge) {
        string memory chainAlias = ChainsLib.chainAlias();
        string memory cofigName = vm.envString("CONFIG");

        ChildChainGaugeDeploymentConfig memory config = ChildChainGaugeConfigsParser.getConfig(
            chainAlias,
            cofigName
        );

        address hookReceiver = _resolveSiloHookReceiver(config.silo, config.asset, config.token);

        IChildChainGaugeFactory factory = IChildChainGaugeFactory(
            VeSiloDeployments.get(
                VeSiloContracts.CHILD_CHAIN_GAUGE_FACTORY,
                chainAlias
            )
        );

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);
        gauge = factory.create(hookReceiver);
        vm.stopBroadcast();

        ChildChainGaugesDeployments.save(chainAlias, cofigName, gauge);
    }
}
