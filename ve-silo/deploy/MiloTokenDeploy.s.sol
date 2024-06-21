// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";

import {ISiloToken} from "ve-silo/contracts/governance/interfaces/ISiloToken.sol";
import {MiloToken} from "ve-silo/contracts/governance/milo-token/MiloToken.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/deploy/MiloTokenDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract MiloTokenDeploy is CommonDeploy {
    function run() public returns (ISiloToken token) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        token = ISiloToken(address(new MiloToken()));

        vm.stopBroadcast();

        _registerDeployment(address(token), VeSiloContracts.MILO_TOKEN);
    }
}
