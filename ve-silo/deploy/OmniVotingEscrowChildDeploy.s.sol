// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {OmniVotingEscrowChild} from "lz_gauges/OmniVotingEscrowChild.sol";

import {VeSiloAddrKey} from "ve-silo/common/VeSiloAddresses.sol";
import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";
import {IOmniVotingEscrowChild} from "ve-silo/contracts/voting-escrow/interfaces/IOmniVotingEscrowChild.sol";

/**
FOUNDRY_PROFILE=ve-silo \
    forge script ve-silo/deploy/OmniVotingEscrowChildDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract OmniVotingEscrowChildDeploy is CommonDeploy {
    function run() public returns (IOmniVotingEscrowChild omniVitingEscrowChild) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

       address lzEndpoint = getAddress(VeSiloAddrKey.LZ_ENDPOINT);
       address delegationHook = getDeployedAddress(VeSiloContracts.L2_LAYER_ZERO_BRIDGE_FORWARDER);

        omniVitingEscrowChild = IOmniVotingEscrowChild(address(
            new OmniVotingEscrowChild(lzEndpoint, delegationHook)
        ));

        _registerDeployment(address(omniVitingEscrowChild), VeSiloContracts.OMNI_VOTING_ESCROW_CHILD);

        vm.stopBroadcast();

        _syncDeployments();
    }
}
