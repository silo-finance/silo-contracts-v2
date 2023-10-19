// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";

import {IStakelessGaugeCheckpointerAdaptor}
    from "ve-silo/contracts/gauges/interfaces/IStakelessGaugeCheckpointerAdaptor.sol";

import {AddrKey} from "common/addresses/AddrKey.sol";
import {IGaugeAdder} from "ve-silo/contracts/gauges/interfaces/IGaugeAdder.sol";
import {ICCIPGaugeCheckpointer} from "ve-silo/contracts/gauges/interfaces/ICCIPGaugeCheckpointer.sol";
import {CCIPGaugeCheckpointer} from "ve-silo/contracts/gauges/stakeless-gauge/CCIPGaugeCheckpointer.sol";

/**
FOUNDRY_PROFILE=ve-silo \
    forge script ve-silo/deploy/CCIPGaugeCheckpointerDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract CCIPGaugeCheckpointerDeploy is CommonDeploy {
    function run() public returns (ICCIPGaugeCheckpointer checkpointer) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        address gaugeAdder = getDeployedAddress(VeSiloContracts.GAUGE_ADDER);
        address checkpointerAdaptor = getDeployedAddress(VeSiloContracts.STAKELESS_GAUGE_CHECKPOINTER_ADAPTOR);

        checkpointer = ICCIPGaugeCheckpointer(address(
            new CCIPGaugeCheckpointer(
                IGaugeAdder(gaugeAdder),
                IStakelessGaugeCheckpointerAdaptor(checkpointerAdaptor),
                getAddress(AddrKey.LINK)
            )
        ));
        
        vm.stopBroadcast();

        _registerDeployment(address(checkpointer), VeSiloContracts.CCIP_GAUGE_CHECKPOINTER);

        _syncDeployments();
    }
}
