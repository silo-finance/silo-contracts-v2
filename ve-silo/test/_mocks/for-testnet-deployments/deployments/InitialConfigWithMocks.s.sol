// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

import {CommonDeploy} from "ve-silo/deploy/_CommonDeploy.sol";
import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";
import {CCIPRouterClientLike} from "ve-silo/test/_mocks/for-testnet-deployments/ccip/CCIPRouterClientLike.sol";
import {IGaugeController} from "ve-silo/contracts/gauges/interfaces/IGaugeController.sol";
import {IGaugeAdder} from "ve-silo/contracts/gauges/interfaces/IGaugeAdder.sol";
import {CCIPGaugeFactory} from "ve-silo/contracts/gauges/ccip/CCIPGaugeFactory.sol";
import {VeSiloMocksContracts} from "./VeSiloMocksContracts.sol";
import {ILiquidityGaugeFactory} from "ve-silo/contracts/gauges/interfaces/ILiquidityGaugeFactory.sol";
import {ICCIPGaugeCheckpointer} from "ve-silo/contracts/gauges/interfaces/ICCIPGaugeCheckpointer.sol";
import {ICCIPGauge} from "ve-silo/contracts/gauges/interfaces/ICCIPGauge.sol";
import {IBalancerTokenAdmin} from "ve-silo/contracts/silo-tokens-minter/MainnetBalancerMinter.sol";

import {
    IStakelessGaugeCheckpointerAdaptor
} from "ve-silo/contracts/gauges/interfaces/IStakelessGaugeCheckpointerAdaptor.sol";

/**
FOUNDRY_PROFILE=ve-silo \
    forge script ve-silo/test/_mocks/for-testnet-deployments/deployments/InitialConfigWithMocks.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract InitialConfigWithMocks is CommonDeploy {
    string constant public GAUGE_TYPE_MC = "MainChain";
    string constant public GAUGE_TYPE_CC = "ChildChain";

    function run() public returns (address gauge) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        string memory chainAlias = getChainAlias();

        IGaugeController controller = IGaugeController(VeSiloDeployments.get(
            VeSiloContracts.GAUGE_CONTROLLER,
            chainAlias
        ));

        IGaugeAdder gaugeAdder = IGaugeAdder(VeSiloDeployments.get(VeSiloContracts.GAUGE_ADDER, chainAlias));
        address gaugeFactoryAddr = VeSiloDeployments.get(VeSiloContracts.LIQUIDITY_GAUGE_FACTORY, chainAlias);
        address siloToken = getAddress(SILO_TOKEN);

        address gaugeFactoryAnyChainAddr = VeSiloDeployments.get(
            VeSiloMocksContracts.CCIP_GAUGE_FACTORY_ANY_CHAIN,
            chainAlias
        );

        ICCIPGaugeCheckpointer ccipCheckpointer = ICCIPGaugeCheckpointer(
            VeSiloDeployments.get(VeSiloContracts.CCIP_GAUGE_CHECKPOINTER, chainAlias)
        );

        IStakelessGaugeCheckpointerAdaptor checkpointerAdaptor = IStakelessGaugeCheckpointerAdaptor(
            VeSiloDeployments.get(VeSiloContracts.STAKELESS_GAUGE_CHECKPOINTER_ADAPTOR, chainAlias)
        );

        IBalancerTokenAdmin balancerTokenAdmin = IBalancerTokenAdmin(
            VeSiloDeployments.get(VeSiloContracts.BALANCER_TOKEN_ADMIN, chainAlias)
        );

        vm.startBroadcast(deployerPrivateKey);

        Ownable(siloToken).transferOwnership(address(balancerTokenAdmin));

        balancerTokenAdmin.activate();

        controller.add_type(GAUGE_TYPE_MC);
        controller.add_type(GAUGE_TYPE_CC);
        controller.set_gauge_adder(address(gaugeAdder));

        gaugeAdder.addGaugeType(GAUGE_TYPE_MC);
        gaugeAdder.addGaugeType(GAUGE_TYPE_CC);

        gaugeAdder.setGaugeFactory(ILiquidityGaugeFactory(gaugeFactoryAddr), GAUGE_TYPE_MC);
        gaugeAdder.setGaugeFactory(ILiquidityGaugeFactory(gaugeFactoryAnyChainAddr), GAUGE_TYPE_CC);

        gauge = CCIPGaugeFactory(gaugeFactoryAnyChainAddr).create(address(gaugeAdder), 1e18 /** weight cap */);

        gaugeAdder.addGauge(gauge, GAUGE_TYPE_CC);

        ICCIPGauge[] memory gauges = new ICCIPGauge[](1);
        gauges[0] = ICCIPGauge(gauge);

        ccipCheckpointer.addGauges(GAUGE_TYPE_CC, gauges);

        checkpointerAdaptor.setStakelessGaugeCheckpointer(address(ccipCheckpointer));

        vm.stopBroadcast();
    }
}
