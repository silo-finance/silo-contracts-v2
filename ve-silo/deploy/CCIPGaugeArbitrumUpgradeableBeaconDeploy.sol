// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IBeacon} from "openzeppelin5/proxy/beacon/IBeacon.sol";

import {CommonDeploy} from "./_CommonDeploy.sol";
import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";

import {
    CCIPGaugeArbitrumUpgradeableBeacon
} from "ve-silo/contracts/gauges/ccip/arbitrum/CCIPGaugeArbitrumUpgradeableBeacon.sol";

import {ICCIPGauge} from "ve-silo/contracts/gauges/interfaces/ICCIPGauge.sol";
import {IMainnetBalancerMinter} from "ve-silo/contracts/silo-tokens-minter/interfaces/IMainnetBalancerMinter.sol";

import {AddrKey} from "common/addresses/AddrKey.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/deploy/CCIPGaugeArbitrumUpgradeableBeaconDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract CCIPGaugeArbitrumUpgradeableBeaconDeploy is CommonDeploy {
    bytes32 constant internal _CHAIN_ALIAS = keccak256(abi.encodePacked("arbitrum_one"));

    error UnsupportedChain();

    function run() public returns (IBeacon beacon) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        string memory chainAlias = getChainAlias();

        if (keccak256(abi.encodePacked(chainAlias)) != _CHAIN_ALIAS) revert UnsupportedChain();

        address gaugeImplementation = VeSiloDeployments.get(VeSiloContracts.CCIP_GAUGE_ARBITRUM, chainAlias);
        address initialOwner = VeSiloDeployments.get(VeSiloContracts.TIMELOCK_CONTROLLER, chainAlias);

        vm.startBroadcast(deployerPrivateKey);

        beacon = IBeacon(address(new CCIPGaugeArbitrumUpgradeableBeacon(gaugeImplementation, initialOwner)));

        vm.stopBroadcast();

        _registerDeployment(address(beacon), VeSiloContracts.CCIP_GAUGE_UPGRADABLE_BEACON);
    }
}
