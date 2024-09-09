// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Governor, IGovernor, SafeCast} from "openzeppelin5/governance/Governor.sol";
import {GovernorSettings} from "openzeppelin5/governance/extensions/GovernorSettings.sol";
import {GovernorCountingSimple} from "openzeppelin5/governance/extensions/GovernorCountingSimple.sol";
import {GovernorVotes, IVotes} from "openzeppelin5/governance/extensions/GovernorVotes.sol";

import {GovernorVotesQuorumFraction}
    from "openzeppelin5/governance/extensions/GovernorVotesQuorumFraction.sol";

import {GovernorTimelockControl, TimelockController}
    from "openzeppelin5/governance/extensions/GovernorTimelockControl.sol";

import {IVeSilo} from "../voting-escrow/interfaces/IVeSilo.sol";

/// @title Silo Governor
/// @notice Silo Governance contract
/// @custom:security-contact security@silo.finance
contract SiloGovernor is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl
{
    IVeSilo public veSiloToken;

    /// @dev Revert if veSiloToken is already intialized
    error VeSiloAlreadyInitialized();

    /// @param _timelock openzeppelin timelock contract
    constructor(TimelockController _timelock, IVeSilo _veSilo)
        Governor("SiloGovernor")
        GovernorSettings(
            1 /* initial voting deplay - 1 block */,
            1 weeks /* initial voting period - 1 week */,
            100_000e18 /* initial proposal threshold - 100k voting power */
        )
        GovernorVotesQuorumFraction(1 /* quorum numerator value */)
        GovernorVotes(IVotes(address(0)))
        GovernorTimelockControl(_timelock)
    {
        veSiloToken = _veSilo;
    }

    /// @inheritdoc IGovernor
    function quorum(uint256 _timepoint)
        public
        view
        virtual
        override(Governor, GovernorVotesQuorumFraction)
        returns (uint256)
    {
        return (veSiloToken.totalSupply(_timepoint) * quorumNumerator(_timepoint)) / quorumDenominator();
    }

    /// @inheritdoc Governor
    function state(uint256 _proposalId)
        public
        view
        virtual
        override(Governor, GovernorTimelockControl)
        returns (ProposalState)
    {
        return GovernorTimelockControl.state(_proposalId);
    }

    /// @inheritdoc Governor
    function proposalThreshold()
        public
        view
        virtual
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return GovernorSettings.proposalThreshold();
    }

    /// @inheritdoc Governor
    function supportsInterface(bytes4 _interfaceId)
        public
        view
        virtual
        override(Governor)
        returns (bool)
    {
        return Governor.supportsInterface(_interfaceId);
    }

    /// @inheritdoc GovernorTimelockControl
    function proposalNeedsQueuing(uint256 _proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (bool)
    {
        return GovernorTimelockControl.proposalNeedsQueuing(_proposalId);
    }

    /// @inheritdoc GovernorVotes
    function clock() public view virtual override(Governor, GovernorVotes) returns (uint48) {
         return SafeCast.toUint48(block.timestamp);
    }

    /// @inheritdoc GovernorVotes
    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public pure virtual override(Governor, GovernorVotes) returns (string memory) {
        return "mode=blocktimestamp&from=default";
    }

    /// @inheritdoc Governor
    function _executeOperations(
        uint256 _proposalId,
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        bytes32 _descriptionHash
    )
        internal
        virtual
        override(Governor, GovernorTimelockControl)
    {
        GovernorTimelockControl._executeOperations(_proposalId, _targets, _values, _calldatas, _descriptionHash);
    }

    /// @inheritdoc GovernorTimelockControl
    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    )
        internal
        virtual
        override(Governor, GovernorTimelockControl)
        returns (uint48)
    {
        return GovernorTimelockControl._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    /// @inheritdoc Governor
    function _cancel(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        bytes32 _descriptionHash
    )
        internal
        override(Governor, GovernorTimelockControl)
        returns (uint256)
    {
        return GovernorTimelockControl._cancel(_targets, _values, _calldatas, _descriptionHash);
    }

    /// @inheritdoc Governor
    function _executor()
        internal
        view
        virtual
        override(Governor, GovernorTimelockControl)
        returns (address)
    {
        return GovernorTimelockControl._executor();
    }

    /// @inheritdoc GovernorVotes
    function _getVotes(
        address _account,
        uint256 _blockNumber,
        bytes memory /* params */
    )
        internal
        view
        virtual
        override(Governor, GovernorVotes)
        returns (uint256)
    {
        return veSiloToken.balanceOf(_account, _blockNumber);
    }
}
