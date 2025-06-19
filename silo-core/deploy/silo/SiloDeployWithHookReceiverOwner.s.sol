// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {SiloDeploy, ISiloDeployer} from "./SiloDeploy.s.sol";

/**
FOUNDRY_PROFILE=core CONFIG=Silo_WAVAX_USDC HOOK_RECEIVER_OWNER=DAO \
    forge script silo-core/deploy/silo/SiloDeployWithHookReceiverOwner.s.sol \
    --ffi --rpc-url $RPC_AVALANCHE --broadcast --verify

Resume verification:
    FOUNDRY_PROFILE=core CONFIG=Silo_WAVAX_USDC HOOK_RECEIVER_OWNER=DAO \
    forge script silo-core/deploy/silo/SiloDeployWithHookReceiverOwner.s.sol \
        --ffi --rpc-url $RPC_AVALANCHE \
        --verify \
        --private-key $PRIVATE_KEY \
        --resume
 */
contract SiloDeployWithHookReceiverOwner is SiloDeploy {
    function _getClonableHookReceiverConfig(address _implementation)
        internal
        override
        returns (ISiloDeployer.ClonableHookReceiver memory hookReceiver)
    {
        string memory hookReceiverOwnerKey = vm.envString("HOOK_RECEIVER_OWNER");

        address hookReceiverOwner = AddrLib.getAddress(hookReceiverOwnerKey);

        hookReceiver = ISiloDeployer.ClonableHookReceiver({
            implementation: _implementation,
            initializationData: abi.encode(hookReceiverOwner)
        });
    }
}

