// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {IProposalEngine} from "proposals/contracts/interfaces/IProposalEngine.sol";
import {ProposalEngineLib} from "./ProposalEngineLib.sol";
import {GaugeAdderProposer} from "./proposers/ve-silo/GaugeAdderProposer.sol";
import {GaugeControllerProposer} from "./proposers/ve-silo/GaugeControllerProposer.sol";

abstract contract Proposal {
    IProposalEngine public constant ENGINE = IProposalEngine(ProposalEngineLib._ENGINE_ADDR);

    GaugeAdderProposer public gaugeAdder;
    GaugeControllerProposer public gaugeController;

    uint256 private _proposalId;

    constructor() {
        ProposalEngineLib.initializeEngine();
        _initializeProposers();
    }

    function getTargets() external view returns (address[] memory targets) {
        targets = ENGINE.getTargets(address(this));
    }

    function getValues() external view returns (uint256[] memory values) {
        values = ENGINE.getValues(address(this));
    }

    function getCalldatas() external view returns (bytes[] memory calldatas) {
        calldatas = ENGINE.getCalldatas(address(this));
    }

    function getProposalId() external view returns (uint256 proposalId) {
        proposalId = _proposalId;
    }

    function getDescription() external view returns (string memory description) {
        description = ENGINE.getDescription(address(this));
    }

    function setProposerPK(uint256 _voterPK) public returns (Proposal) {
        ENGINE.setProposerPK(_voterPK);

        return this;
    }

    function proposeProposal(string memory _proposalDescription) public returns (uint256 proposalId) {
        proposalId = ENGINE.proposeProposal(_proposalDescription);
        _proposalId = proposalId;
    }

     function run() public virtual returns (uint256 propopsalId) {}

    function _initializeProposers() private {
        gaugeAdder = new GaugeAdderProposer({_proposal: address(this)});
        gaugeController = new GaugeControllerProposer({_proposal: address(this)});
    }
}
