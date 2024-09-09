// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";

import {ISiloTokenChildChain} from "ve-silo/contracts/governance/interfaces/ISiloTokenChildChain.sol";
import {MiloTokenChildChain} from "ve-silo/contracts/governance/milo-token/MiloTokenChildChain.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/deploy/MiloTokenChildChainDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract MiloTokenChildChainDeploy is CommonDeploy {
    function run() public returns (ISiloTokenChildChain token) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        token = ISiloTokenChildChain(address(new MiloTokenChildChain()));

        vm.stopBroadcast();

        _registerDeployment(address(token), VeSiloContracts.MILO_TOKEN_CHILD_CHAIN);
    }
}
