// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {VmLib} from "silo-foundry-utils/lib/VmLib.sol";
import {Script} from "forge-std/Script.sol";

import {VeSiloDeployments, VeSiloContracts} from "ve-silo/common/VeSiloContracts.sol";
import {ISiloGovernor} from "ve-silo/contracts/governance/interfaces/ISiloGovernor.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    PROPOSAL_ID=61332815977526359452062364756689834637297063901428295829313706326457022550575 \
    forge script ve-silo/test/milo-ccip-test/scripts/CastVote.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract CastVote is Script {
    function run() external {
        AddrLib.init();
        VmLib.vm().label(AddrLib._ADDRESS_COLLECTION, "AddressesCollection");

        uint256 proposerPrivateKey = uint256(vm.envBytes32("PROPOSER_PRIVATE_KEY"));
        uint256 proposalId = vm.envUint("PROPOSAL_ID");

        string memory chainAlias = ChainsLib.chainAlias();

        address governor = VeSiloDeployments.get(VeSiloContracts.SILO_GOVERNOR, chainAlias);

        vm.startBroadcast(proposerPrivateKey);

        ISiloGovernor(governor).castVote(proposalId, 1);

        vm.stopBroadcast();
    }
}
