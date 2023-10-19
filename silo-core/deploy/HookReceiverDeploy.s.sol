// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {CommonDeploy, SiloCoreContracts} from "./_CommonDeploy.sol";
import {HookReceiver} from "silo-core/contracts/utils/HookReceiver.sol";
import {IHookReceiver} from "silo-core/contracts/interfaces/IHookReceiver.sol";

/**
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/HookReceiverDeploy.s.sol \
        --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract HookReceiverDeploy is CommonDeploy {
    function run() public returns (IHookReceiver hookReceiver) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        hookReceiver = IHookReceiver(address(new HookReceiver()));

        vm.stopBroadcast();

        _registerDeployment(address(hookReceiver), SiloCoreContracts.HOOK_RECEIVER);
    }
}
