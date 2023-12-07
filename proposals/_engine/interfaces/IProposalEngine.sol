// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

interface IProposalEngine {
    function executeProposal(string memory _description) external returns (uint256 proposalId);
    function setGovernor(address _governor) external;
    function addAction(address _target, uint256 _value, bytes calldata _data) external;
}
