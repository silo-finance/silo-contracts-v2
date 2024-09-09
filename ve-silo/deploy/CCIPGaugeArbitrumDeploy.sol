// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {CommonDeploy} from "./_CommonDeploy.sol";
import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";

import {CCIPGaugeArbitrum} from "ve-silo/contracts/gauges/ccip/arbitrum/CCIPGaugeArbitrum.sol";
import {ICCIPGauge} from "ve-silo/contracts/gauges/interfaces/ICCIPGauge.sol";
import {IMainnetBalancerMinter} from "ve-silo/contracts/silo-tokens-minter/interfaces/IMainnetBalancerMinter.sol";

import {AddrKey} from "common/addresses/AddrKey.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/deploy/CCIPGaugeArbitrumDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract CCIPGaugeArbitrumDeploy is CommonDeploy {
    bytes32 constant internal _CHAIN_ALIAS = keccak256(abi.encodePacked("arbitrum_one"));

    error UnsupportedChain();

    function run() public returns (ICCIPGauge gaugeImplementation) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        string memory chainAlias = getChainAlias();

        if (keccak256(abi.encodePacked(chainAlias)) != _CHAIN_ALIAS) revert UnsupportedChain();

        address mainnetBalancerMinter = VeSiloDeployments.get(VeSiloContracts.MAINNET_BALANCER_MINTER, chainAlias);

        vm.startBroadcast(deployerPrivateKey);

        gaugeImplementation = ICCIPGauge(
            address(new CCIPGaugeArbitrum(IMainnetBalancerMinter(mainnetBalancerMinter)))
        );

        vm.stopBroadcast();

        _registerDeployment(address(gaugeImplementation), VeSiloContracts.CCIP_GAUGE_ARBITRUM);
    }
}
