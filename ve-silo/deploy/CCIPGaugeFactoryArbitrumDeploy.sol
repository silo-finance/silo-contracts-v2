// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Ownable} from "openzeppelin5/access/Ownable.sol";

import {CommonDeploy} from "./_CommonDeploy.sol";
import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";

import {CCIPGaugeFactory} from "ve-silo/contracts/gauges/ccip/CCIPGaugeFactory.sol";
import {CCIPGaugeFactoryArbitrum} from "ve-silo/contracts/gauges/ccip/arbitrum/CCIPGaugeFactoryArbitrum.sol";

import {AddrKey} from "common/addresses/AddrKey.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/deploy/CCIPGaugeFactoryArbitrumDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract CCIPGaugeFactoryArbitrumDeploy is CommonDeploy {
    bytes32 constant internal _CHAIN_ALIAS = keccak256(abi.encodePacked("arbitrum_one"));

    error UnsupportedChain();

    function run() public returns (CCIPGaugeFactory factory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        string memory chainAlias = getChainAlias();

        if (keccak256(abi.encodePacked(chainAlias)) != _CHAIN_ALIAS) revert UnsupportedChain();

        address beacon = VeSiloDeployments.get(VeSiloContracts.CCIP_GAUGE_UPGRADABLE_BEACON, chainAlias);
        address checkpointer = VeSiloDeployments.get(VeSiloContracts.STAKELESS_GAUGE_CHECKPOINTER_ADAPTOR, chainAlias);
        address timelock = VeSiloDeployments.get(VeSiloContracts.TIMELOCK_CONTROLLER, chainAlias);

        vm.startBroadcast(deployerPrivateKey);

        factory = CCIPGaugeFactory(address(new CCIPGaugeFactoryArbitrum(beacon, checkpointer)));

        Ownable(address(factory)).transferOwnership(timelock);

        vm.stopBroadcast();

        _registerDeployment(address(factory), VeSiloContracts.CCIP_GAUGE_FACTORY_ARBITRUM);
    }
}
