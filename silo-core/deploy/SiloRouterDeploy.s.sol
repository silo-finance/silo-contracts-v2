// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CommonDeploy} from "./_CommonDeploy.sol";
import {SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";
import {SiloRouter} from "silo-core/contracts/silo-router/SiloRouter.sol";
import {SiloRouterImplementation} from "silo-core/contracts/silo-router/SiloRouterImplementation.sol";

/**
    ETHERSCAN_API_KEY=$VERIFIER_API_KEY_SONIC \
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/SiloRouterDeploy.s.sol \
        --ffi --rpc-url http://127.0.0.1:8545 --broadcast --verify
 */
contract SiloRouterDeploy is CommonDeploy {
    function run() public returns (SiloRouter siloRouter) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        SiloRouterImplementation implementation = new SiloRouterImplementation();

        siloRouter = new SiloRouter(deployer, address(implementation));

        vm.stopBroadcast();

        _registerDeployment(address(siloRouter), SiloCoreContracts.SILO_ROUTER);
    }
}
