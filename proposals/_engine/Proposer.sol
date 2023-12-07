// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {IProposalEngine} from "ve-silo/proposals/_engine/interfaces/IProposalEngine.sol";
import {ProposalEngineLib} from "./ProposalEngineLib.sol";

abstract contract Proposer {
    IProposalEngine public immutable PROPOSAL_ENGINE;

    error DeploymentNotFound(string name, string network);

    constructor() {
        PROPOSAL_ENGINE = IProposalEngine(ProposalEngineLib.ENGINE_ADDR);
    }
}
