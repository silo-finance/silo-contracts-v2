// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CommonDeploy} from "./_CommonDeploy.sol";
import {SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";
import {GaugeHookReceiver} from "silo-core/contracts/utils/hook-receivers/gauge/GaugeHookReceiver.sol";
import {IGaugeHookReceiver} from "silo-core/contracts/interfaces/IGaugeHookReceiver.sol";

/**
    note: when using `FOUNDRY_PROFILE` for deploying new market, foundry can not access oracle files
    and can not verify oracle contracts

    ETHERSCAN_API_KEY=$ARBISCAN_API_KEY \
        forge script silo-core/deploy/GaugeHookReceiverDeploy.s.sol \
        --ffi --broadcast --rpc-url http://127.0.0.1:8545 --verify

    code verification:

    FOUNDRY_PROFILE=core forge verify-contract 0x51De49d2B4f62812362807C47c764Dc8e98Ec689 \
    silo-core/contracts/utils/hook-receivers/gauge/GaugeHookReceiver.sol:GaugeHookReceiver \
    --compiler-version 0.8.28 \
    --rpc-url $RPC_ARBITRUM \
    --watch
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
