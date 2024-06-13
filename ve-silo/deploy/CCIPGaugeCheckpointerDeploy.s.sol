// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Ownable} from "openzeppelin5/access/Ownable.sol";

import {CommonDeploy} from "./_CommonDeploy.sol";
import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";

import {IStakelessGaugeCheckpointerAdaptor}
    from "ve-silo/contracts/gauges/interfaces/IStakelessGaugeCheckpointerAdaptor.sol";

import {AddrKey} from "common/addresses/AddrKey.sol";
import {IGaugeAdder} from "ve-silo/contracts/gauges/interfaces/IGaugeAdder.sol";
import {ICCIPGaugeCheckpointer} from "ve-silo/contracts/gauges/interfaces/ICCIPGaugeCheckpointer.sol";
import {CCIPGaugeCheckpointer} from "ve-silo/contracts/gauges/stakeless-gauge/CCIPGaugeCheckpointer.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/deploy/CCIPGaugeCheckpointerDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract CCIPGaugeCheckpointerDeploy is CommonDeploy {
    function run() public returns (ICCIPGaugeCheckpointer checkpointer) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        string memory chainAlias = getChainAlias();

        address gaugeAdder = VeSiloDeployments.get(VeSiloContracts.GAUGE_ADDER, chainAlias);
        address timelock = VeSiloDeployments.get(VeSiloContracts.TIMELOCK_CONTROLLER, chainAlias);

        address checkpointerAdaptor = VeSiloDeployments.get(
            VeSiloContracts.STAKELESS_GAUGE_CHECKPOINTER_ADAPTOR,
            chainAlias
        );

        vm.startBroadcast(deployerPrivateKey);

        checkpointer = ICCIPGaugeCheckpointer(address(
            new CCIPGaugeCheckpointer(
                IGaugeAdder(gaugeAdder),
                IStakelessGaugeCheckpointerAdaptor(checkpointerAdaptor),
                getAddress(AddrKey.LINK)
            )
        ));

        Ownable(address(checkpointer)).transferOwnership(timelock);
        
        vm.stopBroadcast();

        _registerDeployment(address(checkpointer), VeSiloContracts.CCIP_GAUGE_CHECKPOINTER);
    }
}
