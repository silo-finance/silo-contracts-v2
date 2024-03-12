// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {CommonDeploy, SiloCoreContracts} from "./_CommonDeploy.sol";
import {SiloLens} from "silo-core/contracts/SiloLens.sol";
import {ISiloLens} from "silo-core/contracts/interfaces/ISiloLens.sol";

/**
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/SiloLensDeploy.s.sol \
        --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract SiloLensDeploy is CommonDeploy {
    function run() public returns (ISiloLens siloLens) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        siloLens = ISiloLens(address(new SiloLens()));

        vm.stopBroadcast();

        _registerDeployment(address(siloLens), SiloCoreContracts.SILO_LENS);
    }
}
