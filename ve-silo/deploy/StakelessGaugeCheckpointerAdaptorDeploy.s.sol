// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";

import {IStakelessGaugeCheckpointerAdaptor}
    from "ve-silo/contracts/gauges/interfaces/IStakelessGaugeCheckpointerAdaptor.sol";

import {StakelessGaugeCheckpointerAdaptor}
    from "ve-silo/contracts/gauges/stakeless-gauge/StakelessGaugeCheckpointerAdaptor.sol";

/**
FOUNDRY_PROFILE=ve-silo \
    forge script ve-silo/deploy/StakelessGaugeCheckpointerAdaptorDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract StakelessGaugeCheckpointerAdaptorDeploy is CommonDeploy {
    function run() public returns (IStakelessGaugeCheckpointerAdaptor adaptor) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        adaptor = IStakelessGaugeCheckpointerAdaptor(address(
            new StakelessGaugeCheckpointerAdaptor()
        ));
        
        vm.stopBroadcast();

        _registerDeployment(address(adaptor), VeSiloContracts.STAKELESS_GAUGE_CHECKPOINTER_ADAPTOR);

        _syncDeployments();
    }
}
