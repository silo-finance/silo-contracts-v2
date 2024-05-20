// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IGaugeController} from "ve-silo/contracts/gauges/interfaces/IGaugeController.sol";
import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/deploy/GaugeControllerDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract GaugeControllerDeploy is CommonDeploy {
    string internal constant _BASE_DIR = "ve-silo/contracts/gauges/controller";

    function run() public returns (IGaugeController gaugeController) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        address votingEscrow = getDeployedAddress(VeSiloContracts.VOTING_ESCROW);
        address timelock = getDeployedAddress(VeSiloContracts.TIMELOCK_CONTROLLER);

        vm.startBroadcast(deployerPrivateKey);

         address gaugeControllerAddr = _deploy(
            VeSiloContracts.GAUGE_CONTROLLER,
            abi.encode(votingEscrow, timelock)
         );

        vm.stopBroadcast();

        gaugeController = IGaugeController(gaugeControllerAddr);

        _syncDeployments();
    }

    function _contractBaseDir() internal pure override virtual returns (string memory) {
        return _BASE_DIR;
    }
}
