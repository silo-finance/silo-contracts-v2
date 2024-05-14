// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IProposalEngine} from "proposals/contracts/interfaces/IProposalEngine.sol";
import {ProposalEngineLib} from "./ProposalEngineLib.sol";

/// @notice Proposer is a contract that creates a proposal actions in the proposal engine.
/// @dev Designed to be inherited by the proposer contracts. Proposer contracts should expose the same interface
/// as the contracts that they describe. For example, if the proposer contract describes the `GaugeAdder` contract,
/// it should expose the same interface as the `GaugeAdder` contract. But, each function should create a proposal
/// action in the proposal engine instead of executing the logic that is described in the `GaugeAdder`.
abstract contract Proposer {
    /// @notice The address of the proposal script (forge script where proposal logic is described)
    address public immutable PROPOSAL; // solhint-disable-line var-name-mixedcase
    /// @notice The proposal engine contract
    IProposalEngine public immutable PROPOSAL_ENGINE; // solhint-disable-line var-name-mixedcase

    /// @dev Revert if the deployment for the smart contract is not found
    /// @param name The name of the smart contract
    /// @param network The network for which the deployment is not found
    error DeploymentNotFound(string name, string network);

    /// @param _proposal The address of the proposal script (forge script where proposal logic is described)
    constructor(address _proposal) {
        PROPOSAL = _proposal;
        PROPOSAL_ENGINE = IProposalEngine(ProposalEngineLib._ENGINE_ADDR);
    }

    /// @notice Add a proposal action to the proposal engine
    /// @param _target The address of the target contract
    /// (expecting to have an address of the contract that is described by the proposer contract)
    /// @param _value The value of the transaction
    /// @param _input The input data of the transaction (function selector + arguments)
    /// Input for the proposal action can be created in the following ways:
    /// - abi.encodePacked(Ownable2Step.acceptOwnership.selector)
    /// - abi.encodeCall(IGaugeAdder.addGaugeType, _gaugeType);
    /// - aabi.encodeWithSignature("add_type(string,uint256)", _gaugeType, 1e18);
    function _addAction(address _target, uint256 _value, bytes memory _input) internal {
        PROPOSAL_ENGINE.addAction(PROPOSAL, _target, _value, _input);
    }
}
