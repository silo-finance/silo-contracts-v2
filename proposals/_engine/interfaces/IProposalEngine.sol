// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

interface IProposalEngine {
    function proposeProposal(string memory _description) external returns (uint256 proposalId);
    function setGovernor(address _governor) external;
    function setVoterPK(uint256 _pk) external;
    function addAction(address _target, bytes calldata _data) external;
    function addAction(address _target, uint256 _value, bytes calldata _data) external;
    function getTargets(address _proposal) external view returns (address[] memory targets);
    function getValues(address _proposal) external view returns (uint256[] memory values);
    function getCalldatas(address _proposal) external view returns (bytes[] memory calldatas);
    function getDescription(address _proposal) external view returns (string memory description);
}
