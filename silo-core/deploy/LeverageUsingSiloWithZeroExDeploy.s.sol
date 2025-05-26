// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console2} from "forge-std/console2.sol";

import {CommonDeploy} from "./_CommonDeploy.sol";

import {SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";
import {LeverageUsingSiloWithZeroEx} from "silo-core/contracts/leverage/LeverageUsingSiloWithZeroEx.sol";
import {ISiloLens} from "silo-core/contracts/interfaces/ISiloLens.sol";

/**
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/LeverageUsingSiloWithZeroExDeploy.s.sol \
        --ffi --rpc-url $RPC_SONIC --broadcast --verify

    Resume verification:
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/LeverageUsingSiloWithZeroExDeploy.s.sol \
        --ffi --rpc-url $RPC_SONIC \
        --verify \
        --verifier blockscout --verifier-url $VERIFIER_URL_INK \
        --private-key $PRIVATE_KEY \
        --resume

    remember to run `TowerRegistration` script after deployment!
 */
contract LeverageUsingSiloWithZeroExDeploy is CommonDeploy {
    function run() public returns (LeverageUsingSiloWithZeroEx leverage) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        leverage = new LeverageUsingSiloWithZeroEx(deployer);

        vm.stopBroadcast();

        console2.log("LeverageUsingSiloWithZeroEx redeployed - remember to run `TowerRegistration` script!");

        _registerDeployment(address(leverage), SiloCoreContracts.SILO_LEVERAGE_USING_SILO_0X);
    }
}
