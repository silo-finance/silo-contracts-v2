// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";
import {IChildChainGaugeFactory} from "ve-silo/contracts/gauges/interfaces/IChildChainGaugeFactory.sol";
import {ChildChainGaugesDeployments} from "./ChildChainGaugesDeployments.sol";
import {GaugeDeployScript} from "../GaugeDeployScript.sol";

/**
Supported tokens: protectedShareToken | collateralShareToken | debtShareToken
Silo deployments: silo-core/deploy/silo/_siloDeployments.json
MAX_RELATIVE_WEIGHT_CAP = 10 ** 18

FOUNDRY_PROFILE=ve-silo \
    SILO=ETH-USDC_UniswapV3_Silo \
    ASSET=USDC \
    TOKEN=protectedShareToken \
    forge script ve-silo/deploy/gauges/child-chain-gauge/ChildChainGaugeDeployer.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract ChildChainGaugeDeployer is GaugeDeployScript {
    function run() public returns (address gauge) {
        string memory chainAlias = ChainsLib.chainAlias();

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        IChildChainGaugeFactory factory = IChildChainGaugeFactory(
            VeSiloDeployments.get(
                VeSiloContracts.CHILD_CHAIN_GAUGE_FACTORY,
                chainAlias
            )
        );

        address hookReceiver = _resolveSiloHookReceiver();

        vm.startBroadcast(deployerPrivateKey);
        gauge = factory.create(relativeWeightCap, hookReceiver);
        vm.stopBroadcast();

        ChildChainGaugesDeployments.save(
            chainAlias,
            vm.envString("SILO"),
            vm.envString("ASSET"),
            vm.envString("TOKEN"),
            gauge
        );
    }
}
