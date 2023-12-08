// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {VmLib} from "silo-foundry-utils/lib/VmLib.sol";

import {ISiloGovernor} from "ve-silo/contracts/governance/interfaces/ISiloGovernor.sol";
import {IProposalEngine} from "./interfaces/IProposalEngine.sol";

import {console} from "forge-std/console.sol";

contract ProposalEngine is IProposalEngine {
    struct ProposalAction {
        address target;
        uint256 value;
        bytes input;
    }

    ISiloGovernor public siloGovernor;
    // proposal => proposal actions
    mapping(address => ProposalAction[]) public proposalActions;
    // proposal => execution status
    mapping(address => bool) public proposalIsProposed;
    // proposal => description
    mapping(address => string) public proposalDescription;

    uint256 private _voterPK;

    error ProposalIsProposed();

    function addAction(address _target, uint256 _value, bytes calldata _input) external {
        _addAction(_target, _value, _input);
    }

    function addAction(address _target, bytes calldata _input) external {
        _addAction(_target, 0, _input);
    }

    function setGovernor(address _governor) external {
        siloGovernor = ISiloGovernor(_governor);
    }

    function setVoterPK(uint256 _pk) external {
        _voterPK = _pk;
    }

    function proposeProposal(string memory _description) external returns (uint256 proposalId) {
        console.log("proposer while proposing: ", msg.sender);

        if (proposalIsProposed[msg.sender]) revert ProposalIsProposed();

        ProposalAction[] storage actions = proposalActions[msg.sender];

        uint256 actionsLength = actions.length;

        address[] memory targets = new address[](actionsLength);
        uint256[] memory values = new uint256[](actionsLength);
        bytes[] memory calldatas = new bytes[](actionsLength);

        for (uint256 i = 0; i < actionsLength; i++) {
            targets[i] = actions[i].target;
            values[i] = actions[i].value;
            calldatas[i] = actions[i].input;
        }

        uint256 proposerPrivateKey = _getVoterPK();

        VmLib.vm().startBroadcast(proposerPrivateKey);

        proposalId = siloGovernor.propose(
            targets,
            values,
            calldatas,
            _description
        );

        VmLib.vm().stopBroadcast();

        proposalIsProposed[msg.sender] = true;
    }

    function getTargets(address _proposal) external view returns (address[] memory targets) {
        uint256 actionsLength = proposalActions[_proposal].length;
        targets = new address[](actionsLength);

        for (uint256 i = 0; i < actionsLength; i++) {
            targets[i] = proposalActions[_proposal][i].target;
        }
    }

    function getValues(address _proposal) external view returns (uint256[] memory values) {
        uint256 actionsLength = proposalActions[_proposal].length;
        values = new uint256[](actionsLength);

        for (uint256 i = 0; i < actionsLength; i++) {
            values[i] = proposalActions[_proposal][i].value;
        }
    }

    function getCalldatas(address _proposal) external view returns (bytes[] memory calldatas) {
        uint256 actionsLength = proposalActions[_proposal].length;
        calldatas = new bytes[](actionsLength);

        for (uint256 i = 0; i < actionsLength; i++) {
            calldatas[i] = proposalActions[_proposal][i].input;
        }
    }

    function getDescription(address _proposal) external view returns (string memory description) {
        description = proposalDescription[_proposal];
    }

    function _getVoterPK() internal view returns (uint256 pk) {
        if (_voterPK != 0) return _voterPK;

        pk = uint256(VmLib.vm().envBytes32("PROPOSER_PRIVATE_KEY"));
    }

    function _addAction(address _target, uint256 _value, bytes calldata _input) internal {
        console.log("proposer: ", msg.sender);

        if (proposalIsProposed[msg.sender]) revert ProposalIsProposed();

        proposalActions[msg.sender].push(ProposalAction({
            target: _target,
            value: _value,
            input: _input
        }));
    }
}
