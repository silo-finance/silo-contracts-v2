// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {IGaugeController} from "ve-silo/contracts/gauges/interfaces/IGaugeController.sol";
import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";

/**
FOUNDRY_PROFILE=ve-silo \
    forge script ve-silo/deploy/GaugeControllerDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract GaugeControllerDeploy is CommonDeploy {
    string internal constant _BASE_DIR = "ve-silo/contracts/gauges/controller";

    function run() public returns (IGaugeController gaugeController) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

         address gaugeControllerAddr = _deploy(
            VeSiloContracts.GAUGE_CONTROLLER,
            abi.encode(
                getDeployedAddress(VeSiloContracts.VOTING_ESCROW),
                getDeployedAddress(VeSiloContracts.TIMELOCK_CONTROLLER)
            )
         );

        gaugeController = IGaugeController(gaugeControllerAddr);

        vm.stopBroadcast();

        _syncDeployments();
    }

    function _contractBaseDir() internal pure override virtual returns (string memory) {
        return _BASE_DIR;
    }
}
