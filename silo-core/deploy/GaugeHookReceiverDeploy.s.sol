// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {CommonDeploy, SiloCoreContracts} from "./_CommonDeploy.sol";
import {GaugeHookReceiver} from "silo-core/contracts/utils/hook-receivers/gauge/GaugeHookReceiver.sol";
import {IGaugeHookReceiver} from "silo-core/contracts/utils/hook-receivers/gauge/interfaces/IGaugeHookReceiver.sol";

/**
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/GaugeHookReceiverDeploy.s.sol \
        --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract GaugeHookReceiverDeploy is CommonDeploy {
    function run() public returns (IGaugeHookReceiver hookReceiver) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        hookReceiver = IGaugeHookReceiver(address(new GaugeHookReceiver()));

        vm.stopBroadcast();

        _registerDeployment(address(hookReceiver), SiloCoreContracts.GAUGE_HOOK_RECEIVER);
    }
}
