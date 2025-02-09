// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";
import {SiloDeploy, ISiloDeployer} from "./SiloDeploy.s.sol";

/**
FOUNDRY_PROFILE=core CONFIG=solvBTC.BBN_solvBTC \
    forge script silo-core/deploy/silo/SiloDeployWithGaugeHookReceiver.s.sol \
    --ffi --rpc-url $RPC_SONIC --broadcast --verify
 */
contract SiloDeployWithGaugeHookReceiver is SiloDeploy {
    function _getClonableHookReceiverConfig(address _implementation)
        internal
        override
        returns (ISiloDeployer.ClonableHookReceiver memory hookReceiver)
    {
        address timelock = VeSiloDeployments.get(VeSiloContracts.TIMELOCK_CONTROLLER, ChainsLib.chainAlias());

        hookReceiver = ISiloDeployer.ClonableHookReceiver({
            implementation: _implementation,
            initializationData: abi.encode(timelock)
        });
    }
}
