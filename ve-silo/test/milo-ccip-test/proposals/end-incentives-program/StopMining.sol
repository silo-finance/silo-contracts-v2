// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Proposal} from "proposals/contracts/Proposal.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/test/milo-ccip-test/proposals/end-incentives-program/StopMining.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
*/
contract StopMining is Proposal {
    string constant public PROPOSAL_DESCRIPTION = "Stop mining";

    function run() public override returns (uint256 proposalId) {
        initializeActions();

        proposalId = proposeProposal(PROPOSAL_DESCRIPTION);
    }

    function initializeActions() public {
        initBalancerTokenAdmin();

        /* PROPOSAL START */
        balancerTokenAdmin.stopMining();
        /* PROPOSAL END */
    }
}
