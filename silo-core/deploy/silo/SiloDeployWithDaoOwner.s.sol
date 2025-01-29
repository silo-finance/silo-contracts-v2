// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {SiloDeploy, ISiloDeployer} from "./SiloDeploy.s.sol";

/**
FOUNDRY_PROFILE=core CONFIG=solvBTC.BBN_solvBTC \
    forge script silo-core/deploy/silo/SiloDeployWithDaoOwner.s.sol \
    --ffi --rpc-url $RPC_SONIC --broadcast --verify
 */
contract SiloDeployWithDaoOwner is SiloDeploy {
    function _getClonableHookReceiverConfig(address _implementation)
        internal
        view
        override
        returns (ISiloDeployer.ClonableHookReceiver memory hookReceiver)
    {
        address dao = AddrLib.getAddress(AddrKey.DAO);

        hookReceiver = ISiloDeployer.ClonableHookReceiver({
            implementation: _implementation,
            initializationData: abi.encode(dao)
        });
    }
}

