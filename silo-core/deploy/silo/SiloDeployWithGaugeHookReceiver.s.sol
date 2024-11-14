// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {AddrKey} from "common/addresses/AddrKey.sol";
import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";
import {SiloDeploy, ISiloDeployer} from "./SiloDeploy.s.sol";

/**
FOUNDRY_PROFILE=core CONFIG=USDC_UniswapV3_Silo \
    forge script silo-core/deploy/silo/SiloDeployWithGaugeHookReceiver.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract SiloDeployWithGaugeHookReceiver is SiloDeploy {
    function _getClonableHookReceiverConfig(address _implementation)
        internal
        override
        returns (ISiloDeployer.ClonableHookReceiver memory hookReceiver)
    {
        address timelock = _getTimelock();

        hookReceiver = ISiloDeployer.ClonableHookReceiver({
            implementation: _implementation,
            initializationData: abi.encode(timelock)
        }); 
    }

    function _getTimelock() internal returns (address timelock) {
        uint256 chainId = ChainsLib.getChainId();

        if (chainId == ChainsLib.ARBITRUM_ONE_CHAIN_ID || chainId == ChainsLib.ANVIL_CHAIN_ID) {
            timelock = VeSiloDeployments.get(VeSiloContracts.TIMELOCK_CONTROLLER, ChainsLib.ARBITRUM_ONE_ALIAS);
        } else {
            AddrLib.init();
            timelock = AddrLib.getAddress(AddrKey.L2_MULTISIG);
        }
    }
}
