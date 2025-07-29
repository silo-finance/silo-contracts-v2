// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {SiloDeployKink, ISiloDeployer} from "./SiloDeployKink.s.sol";

/**
FOUNDRY_PROFILE=core CONFIG=solvBTC.BBN_solvBTC \
    forge script silo-core/deploy/silo/SiloDeployWithDeployerOwnerKink.s.sol \
    --ffi --rpc-url $RPC_SONIC --broadcast --verify
 */
contract SiloDeployWithDeployerOwnerKink is SiloDeployKink {
    function _getClonableHookReceiverConfig(address _implementation)
        internal
        view
        override
        returns (ISiloDeployer.ClonableHookReceiver memory hookReceiver)
    {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        address owner = vm.addr(deployerPrivateKey);

        hookReceiver = ISiloDeployer.ClonableHookReceiver({
            implementation: _implementation,
            initializationData: abi.encode(owner)
        });
    }
}
