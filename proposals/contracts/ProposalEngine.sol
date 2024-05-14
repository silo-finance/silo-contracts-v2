// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {VmLib} from "silo-foundry-utils/lib/VmLib.sol";

import {ISiloGovernor} from "ve-silo/contracts/governance/interfaces/ISiloGovernor.sol";
import {IProposalEngine} from "./interfaces/IProposalEngine.sol";

/// @notice Proposal engine is a contract that allows to propose a proposal
contract ProposalEngine is IProposalEngine {
    struct ProposalAction {
        address target;
        uint256 value;
        bytes input;
    }

    /// @notice The governor contract (expecting ve-silo/contracts/governance/SiloGovernor)
    ISiloGovernor public siloGovernor;
    // proposal => proposal actions
    mapping(address => ProposalAction[]) public proposalActions;
    // proposal => execution status
    mapping(address => bool) public proposalIsProposed;
    // proposal => description
    mapping(address => string) public proposalDescription;
    // proposer private key (can be set via `setProposerPK` function or `PROPOSER_PRIVATE_KEY` env variable)
    uint256 private _proposerPK;

    /// @dev Revert on an attempt to propose a proposal that is already proposed
    error ProposalIsProposed();

    /// @inheritdoc IProposalEngine
    function addAction(address _proposal, address _target, uint256 _value, bytes calldata _input) external {
        _addAction(_proposal, _target, _value, _input);
    }

    /// @inheritdoc IProposalEngine
    function addAction(address _proposal, address _target, bytes calldata _input) external {
        _addAction(_proposal, _target, 0, _input);
    }

    /// @inheritdoc IProposalEngine
    function setGovernor(address _governor) external {
        siloGovernor = ISiloGovernor(_governor);
    }

    /// @inheritdoc IProposalEngine
    function setProposerPK(uint256 _pk) external {
        _proposerPK = _pk;
    }

    /// @inheritdoc IProposalEngine
    function proposeProposal(string memory _description) external returns (uint256 proposalId) {
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

        uint256 proposerPrivateKey = _getProposerPK();

        VmLib.vm().startBroadcast(proposerPrivateKey);

        proposalId = siloGovernor.propose(
            targets,
            values,
            calldatas,
            _description
        );

        VmLib.vm().stopBroadcast();

        proposalIsProposed[msg.sender] = true;
        proposalDescription[msg.sender] = _description;
    }

    /// @inheritdoc IProposalEngine
    function getTargets(address _proposal) external view returns (address[] memory targets) {
        uint256 actionsLength = proposalActions[_proposal].length;
        targets = new address[](actionsLength);

        for (uint256 i = 0; i < actionsLength; i++) {
            targets[i] = proposalActions[_proposal][i].target;
        }
    }

    /// @inheritdoc IProposalEngine
    function getValues(address _proposal) external view returns (uint256[] memory values) {
        uint256 actionsLength = proposalActions[_proposal].length;
        values = new uint256[](actionsLength);

        for (uint256 i = 0; i < actionsLength; i++) {
            values[i] = proposalActions[_proposal][i].value;
        }
    }

    /// @inheritdoc IProposalEngine
    function getCalldatas(address _proposal) external view returns (bytes[] memory calldatas) {
        uint256 actionsLength = proposalActions[_proposal].length;
        calldatas = new bytes[](actionsLength);

        for (uint256 i = 0; i < actionsLength; i++) {
            calldatas[i] = proposalActions[_proposal][i].input;
        }
    }

    /// @inheritdoc IProposalEngine
    function getDescription(address _proposal) external view returns (string memory description) {
        description = proposalDescription[_proposal];
    }

    function _addAction(address _proposal, address _target, uint256 _value, bytes calldata _input) internal {
        if (proposalIsProposed[_proposal]) revert ProposalIsProposed();

        proposalActions[_proposal].push(ProposalAction(_target, _value, _input));
    }

    function _getProposerPK() internal view returns (uint256 pk) {
        if (_proposerPK != 0) return _proposerPK;

        pk = uint256(VmLib.vm().envBytes32("PROPOSER_PRIVATE_KEY"));
    }
}
