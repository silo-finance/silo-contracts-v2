// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console2} from "forge-std/console2.sol";

import {CommonDeploy} from "./_CommonDeploy.sol";

import {SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";
import {SiloLens} from "silo-core/contracts/SiloLens.sol";
import {ISiloLens} from "silo-core/contracts/interfaces/ISiloLens.sol";

/**
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/SiloLensDeploy.s.sol \
        --ffi --rpc-url $RPC_SONIC --broadcast --verify

    ETHERSCAN_API_KEY=$VERIFIER_API_KEY_SONIC \
    forge verify-contract 0xE05966aee69CeCD677a30f469812Ced650cE3b5E \
        SiloLens \
        --compiler-version 0.8.28 \
        --rpc-url $RPC_SONIC \
        --watch

    remember to run `TowerRegistration` script after deployment!
 */
contract SiloLensDeploy is CommonDeploy {
    function run() public returns (ISiloLens siloLens) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        siloLens = ISiloLens(address(new SiloLens()));

        vm.stopBroadcast();

        console2.log("SiloLens redeployed - remember to run `TowerRegistration` script!");

        _registerDeployment(address(siloLens), SiloCoreContracts.SILO_LENS);
    }
}
