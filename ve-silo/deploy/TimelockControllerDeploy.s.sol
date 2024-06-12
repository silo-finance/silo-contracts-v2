// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";
import {TimelockController} from "openzeppelin5/governance/TimelockController.sol";
import {ISiloTimelockController} from "ve-silo/contracts/governance/interfaces/ISiloTimelockController.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/deploy/TimelockControllerDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract TimelockControllerDeploy is CommonDeploy {
    function run() public returns (ISiloTimelockController timelockController) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        uint256 minDelay = 1;
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](0);
        address admin = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        timelockController = ISiloTimelockController(address(
            new TimelockController(
                minDelay,
                proposers,
                executors,
                admin
            )
        ));

        vm.stopBroadcast();

        _registerDeployment(address(timelockController), VeSiloContracts.TIMELOCK_CONTROLLER);
    }
}
