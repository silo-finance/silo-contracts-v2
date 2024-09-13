// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Ownable2Step} from "openzeppelin5/access/Ownable2Step.sol";

import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";

import {IGaugeController} from "ve-silo/contracts/gauges/interfaces/IGaugeController.sol";
import {GaugeAdder, IGaugeAdder} from "ve-silo/contracts/gauges/gauge-adder/GaugeAdder.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/deploy/GaugeAdderDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract GaugeAdderDeploy is CommonDeploy {
    function run() public returns (IGaugeAdder gaugeAdder) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        address controller = getDeployedAddress(VeSiloContracts.GAUGE_CONTROLLER);
        address timelock = getDeployedAddress(VeSiloContracts.TIMELOCK_CONTROLLER);

        vm.startBroadcast(deployerPrivateKey);

        gaugeAdder = IGaugeAdder(address(new GaugeAdder(IGaugeController(controller))));

        Ownable2Step(address(gaugeAdder)).transferOwnership(timelock);

        vm.stopBroadcast();

        _registerDeployment(address(gaugeAdder), VeSiloContracts.GAUGE_ADDER);
    }
}
