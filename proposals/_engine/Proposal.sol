// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {IProposalEngine} from "ve-silo/proposals/_engine/interfaces/IProposalEngine.sol";
import {ProposalEngineLib} from "./ProposalEngineLib.sol";
import {GaugeAdderProposer} from "./proposers/GaugeAdderProposer.sol";

abstract contract Proposal {
    GaugeAdderProposer public gaugeAdder;

    constructor() {
        ProposalEngineLib.initializeEngine();
        _initializeProposers();
    }

    function executeProposal(string memory _proposalDescription) public returns (uint256 proposalId) {
        IProposalEngine engine = IProposalEngine(ProposalEngineLib.ENGINE_ADDR);
        proposalId = engine.executeProposal(_proposalDescription);
    }

    function _initializeProposers() private {
        gaugeAdder = new GaugeAdderProposer();
    }
}
