// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {CommonDeploy, SiloCoreContracts} from "./_CommonDeploy.sol";
import {IHookReceiversFactory} from "silo-core/contracts/interfaces/IHookReceiversFactory.sol";
import {HookReceiversFactory} from "silo-core/contracts/utils/HookReceiversFactory.sol";

/**
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/HookReceiversFactoryDeploy.s.sol \
        --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract HookReceiversFactoryDeploy is CommonDeploy {
    function run() public returns (IHookReceiversFactory factory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        factory = IHookReceiversFactory(address(new HookReceiversFactory()));

        vm.stopBroadcast();

        _registerDeployment(address(factory), SiloCoreContracts.HOOK_RECEIVERS_FACTORY);
    }
}
