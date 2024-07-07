// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {CommonDeploy, SiloCoreContracts} from "./_CommonDeploy.sol";
import {SiloRouter} from "silo-core/contracts/SiloRouter.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";

/**
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/SiloRouterDeploy.s.sol \
        --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract SiloRouterDeploy is CommonDeploy {
    function run() public returns (SiloRouter siloRouter) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        address weth = AddrLib.getAddress(AddrKey.WETH);

        vm.startBroadcast(deployerPrivateKey);

        siloRouter = new SiloRouter(weth);

        vm.stopBroadcast();

        _registerDeployment(address(siloRouter), SiloCoreContracts.SILO_ROUTER);
    }
}