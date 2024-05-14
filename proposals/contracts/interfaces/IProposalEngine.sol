// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

/// @notice Interface of the proposal engine
/// @dev Proposal engine is a contract that allows to propose a proposal.
/// Requires to specify a governor contract (expecting ve-silo/contracts/governance/SiloGovernor.sol)
/// via `setGovernor` function. And a proposer private key via `setProposerPK` function or
/// `PROPOSER_PRIVATE_KEY` env variable.
interface IProposalEngine {
    /// @notice Propose a proposal
    /// @param _description The description of the proposal
    /// @return proposalId The id of the proposed proposal
    function proposeProposal(string memory _description) external returns (uint256 proposalId);

    /// @notice Set the governor (Expecting ve-silo/contracts/governance/SiloGovernor.sol)
    /// @param _governor The address of the governor
    function setGovernor(address _governor) external;

    /// @notice Set the proposer private key (in case if `PROPOSER_PRIVATE_KEY` env variable is not set)
    /// @param _pk The private key of the proposer
    function setProposerPK(uint256 _pk) external;

    /// @notice Add an action to the proposal
    /// @param _proposal The address of the proposal (proposal script)
    /// @param _target The address of the target contract
    /// @param _input The input data of the transaction (function selector + arguments)
    function addAction(address _proposal, address _target, bytes calldata _input) external;

    /// @notice Add an action to the proposal
    /// @param _proposal The address of the proposal (proposal script)
    /// @param _target The address of the target contract
    /// @param _value The value of the transaction
    /// @param _input The input data of the transaction (function selector + arguments)
    function addAction(address _proposal, address _target, uint256 _value, bytes calldata _input) external;

    /// @notice Get the targets of the proposal
    /// @param _proposal The address of the proposal (proposal script)
    /// @return targets The targets of the proposal
    function getTargets(address _proposal) external view returns (address[] memory targets);

    /// @notice Get the values of the proposal
    /// @param _proposal The address of the proposal (proposal script)
    /// @return values The values of the proposal
    function getValues(address _proposal) external view returns (uint256[] memory values);

    /// @notice Get the calldatas of the proposal
    /// @param _proposal The address of the proposal (proposal script)
    /// @return calldatas The calldatas of the proposal
    function getCalldatas(address _proposal) external view returns (bytes[] memory calldatas);

    /// @notice Get the description of the proposal
    /// @param _proposal The address of the proposal (proposal script)
    /// @return description The description of the proposal
    function getDescription(address _proposal) external view returns (string memory description);
}
