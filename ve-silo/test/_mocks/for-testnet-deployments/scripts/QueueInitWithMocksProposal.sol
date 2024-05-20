// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {VmLib} from "silo-foundry-utils/lib/VmLib.sol";
import {Script} from "forge-std/Script.sol";

import {VeSiloDeployments, VeSiloContracts} from "ve-silo/common/VeSiloContracts.sol";
import {ISiloGovernor} from "ve-silo/contracts/governance/interfaces/ISiloGovernor.sol";
import {SIPV2InitWithMocks} from "ve-silo/test/_mocks/for-testnet-deployments/proposals/SIPV2InitWithMocks.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/_mocks/for-testnet-deployments/scripts/QueueInitWithMocksProposal.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract QueueInitWithMocksProposal is Script {
    function run() external {
        AddrLib.init();
        VmLib.vm().label(AddrLib._ADDRESS_COLLECTION, "AddressesCollection");

        uint256 proposerPrivateKey = uint256(vm.envBytes32("PROPOSER_PRIVATE_KEY"));

        string memory chainAlias = ChainsLib.chainAlias();

        address governor = VeSiloDeployments.get(VeSiloContracts.SILO_GOVERNOR, chainAlias);

        SIPV2InitWithMocks proposal = new SIPV2InitWithMocks();
        proposal.initializeActions();

        address[] memory targets = proposal.getTargets();
        uint256[] memory values = proposal.getValues();
        bytes[] memory calldatas = proposal.getCalldatas();
        string memory description = proposal.PROPOSAL_DESCRIPTION();

        bytes32 descriptionHash = keccak256(bytes(description));

        vm.startBroadcast(proposerPrivateKey);

        ISiloGovernor(governor).queue(
            targets,
            values,
            calldatas,
            descriptionHash
        );

        vm.stopBroadcast();
    }
}
