// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";

import {IStakelessGaugeCheckpointerAdaptor}
    from "ve-silo/contracts/gauges/interfaces/IStakelessGaugeCheckpointerAdaptor.sol";

import {IGaugeAdder} from "ve-silo/contracts/gauges/interfaces/IGaugeAdder.sol";
import {IStakelessGaugeCheckpointer} from "ve-silo/contracts/gauges/interfaces/IStakelessGaugeCheckpointer.sol";
import {StakelessGaugeCheckpointer} from "ve-silo/contracts/gauges/stakeless-gauge/StakelessGaugeCheckpointer.sol";

/**
FOUNDRY_PROFILE=ve-silo \
    forge script ve-silo/deploy/StakelessGaugeCheckpointerDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract StakelessGaugeCheckpointerDeploy is CommonDeploy {
    function run() public returns (IStakelessGaugeCheckpointer checkpointer) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        address gaugeAdder = getDeployedAddress(VeSiloContracts.GAUGE_ADDER);
        address checkpointerAdaptor = getDeployedAddress(VeSiloContracts.STAKELESS_GAUGE_CHECKPOINTER_ADAPTOR);

        checkpointer = IStakelessGaugeCheckpointer(address(
            new StakelessGaugeCheckpointer(
                IGaugeAdder(gaugeAdder),
                IStakelessGaugeCheckpointerAdaptor(checkpointerAdaptor)
            )
        ));
        
        vm.stopBroadcast();

        _registerDeployment(address(checkpointer), VeSiloContracts.STAKELESS_GAUGE_CHECKPOINTER_ADAPTOR);

        _syncDeployments();
    }
}
