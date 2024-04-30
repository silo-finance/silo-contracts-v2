// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {VmLib} from "silo-foundry-utils/lib/VmLib.sol";
import {Script} from "forge-std/Script.sol";
import {GovernorCountingSimple} from "openzeppelin5/governance/extensions/GovernorCountingSimple.sol";
import {TimelockController} from "openzeppelin5/governance/TimelockController.sol";

import {VeSiloDeployments, VeSiloContracts} from "ve-silo/common/VeSiloContracts.sol";
import {ISiloGovernor, IGovernor} from "ve-silo/contracts/governance/interfaces/ISiloGovernor.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    PROPOSAL_ID=30777859449768177335326918358646070044764896023301554175577731398295188897581 \
    forge script ve-silo/test/_mocks/for-testnet-deployments/scripts/ProposalDetails.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545

    cast rpc evm_increaseTime 3601 --rpc-url http://127.0.0.1:8545

    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }
 */
contract ProposalDetails is Script {
    struct Result {
        uint256 snapshot;
        uint256 clock;
        uint256 quorum;
        uint256 proposalEta;
        uint256 proposalDeadline;
        uint256 againstVotes;
        uint256 forVotes;
        uint256 abstainVotes;
        uint256 blockTimestamp;
        uint256 minDelay;
        IGovernor.ProposalState state;
    }

    function run() external returns (Result memory result) {
        AddrLib.init();
        VmLib.vm().label(AddrLib._ADDRESS_COLLECTION, "AddressesCollection");

        uint256 proposalId = vm.envUint("PROPOSAL_ID");

        string memory chainAlias = ChainsLib.chainAlias();

        address governor = VeSiloDeployments.get(VeSiloContracts.SILO_GOVERNOR, chainAlias);
        address timelock = VeSiloDeployments.get(VeSiloContracts.TIMELOCK_CONTROLLER, chainAlias);

        result.snapshot = ISiloGovernor(governor).proposalSnapshot(proposalId);
        result.quorum = ISiloGovernor(governor).quorum(result.snapshot);
        result.clock = ISiloGovernor(governor).clock();
        result.state = ISiloGovernor(governor).state(proposalId);
        result.blockTimestamp = block.timestamp;
        result.proposalEta = ISiloGovernor(governor).proposalEta(proposalId);
        result.proposalDeadline = ISiloGovernor(governor).proposalDeadline(proposalId);
        result.minDelay = TimelockController(payable(timelock)).getMinDelay();

        (
            result.againstVotes,
            result.forVotes,
            result.abstainVotes
        ) = GovernorCountingSimple(payable(governor)).proposalVotes(proposalId);
    }
}
