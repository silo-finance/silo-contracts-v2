// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";
import {IBatchGaugeCheckpointer} from "ve-silo/contracts/gauges/interfaces/IBatchGaugeCheckpointer.sol";
import {BatchGaugeCheckpointer} from "ve-silo/contracts/gauges/l2-common/BatchGaugeCheckpointer.sol";

/**
FOUNDRY_PROFILE=ve-silo \
    forge script ve-silo/deploy/BatchGaugeCheckpointerDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract BatchGaugeCheckpointerDeploy is CommonDeploy {
    function run() public returns (IBatchGaugeCheckpointer checkpointer) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        checkpointer = IBatchGaugeCheckpointer(address(new BatchGaugeCheckpointer()));

        vm.stopBroadcast();

        _registerDeployment(address(checkpointer), VeSiloContracts.BATCH_GAUGE_CHECKPOINTER);
        _syncDeployments();
    }
}
