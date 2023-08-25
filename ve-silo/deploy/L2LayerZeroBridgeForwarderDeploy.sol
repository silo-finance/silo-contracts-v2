// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IL2LayerZeroBridgeForwarder} from "ve-silo/contracts/voting-escrow/interfaces/IL2LayerZeroBridgeForwarder.sol";
import {L2LayerZeroBridgeForwarder} from "ve-silo/contracts/voting-escrow/L2LayerZeroBridgeForwarder.sol";
import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";

/**
FOUNDRY_PROFILE=ve-silo \
    forge script ve-silo/deploy/L2LayerZeroBridgeForwarderDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract L2LayerZeroBridgeForwarderDeploy is CommonDeploy {
    function run() public returns (IL2LayerZeroBridgeForwarder forwarder) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        forwarder = IL2LayerZeroBridgeForwarder(address(new L2LayerZeroBridgeForwarder()));

        vm.stopBroadcast();

        _registerDeployment(address(forwarder), VeSiloContracts.L2_LAYER_ZERO_BRIDGE_FORWARDER);

        _syncDeployments();
    }
}
