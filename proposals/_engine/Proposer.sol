// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {IProposalEngine} from "proposals/_engine/interfaces/IProposalEngine.sol";
import {ProposalEngineLib} from "./ProposalEngineLib.sol";

abstract contract Proposer {
    address public immutable PROPOSAL;
    IProposalEngine public immutable PROPOSAL_ENGINE;

    error DeploymentNotFound(string name, string network);

    constructor(address _proposal) {
        PROPOSAL = _proposal;
        PROPOSAL_ENGINE = IProposalEngine(ProposalEngineLib.ENGINE_ADDR);
    }

    function _addAction(address _target, uint256 _value, bytes memory _input) internal {
        PROPOSAL_ENGINE.addAction(PROPOSAL, _target, _value, _input);
    }
}
