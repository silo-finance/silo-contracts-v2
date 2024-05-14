// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

interface IProposal {
    /// @notice Get the targets of the proposal
    /// @return targets The targets of the proposal
    function getTargets() external view returns (address[] memory targets);

    /// @notice Get the values of the proposal
    /// @return values The values of the proposal
    function getValues() external view returns (uint256[] memory values);

    /// @notice Get the calldatas of the proposal
    /// @return calldatas The calldatas of the proposal
    function getCalldatas() external view returns (bytes[] memory calldatas);

    /// @notice Get the id of the proposed proposal
    /// @dev Is `0` until proposal is porposed
    /// @return proposalId The id of the proposed proposal
    function getProposalId() external view returns (uint256 proposalId);

    /// @notice Get the description of the proposal
    /// @return description The description of the proposal
    function getDescription() external view returns (string memory description);
}
