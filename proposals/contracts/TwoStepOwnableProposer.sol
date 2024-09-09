// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Ownable2Step} from "openzeppelin5/access/Ownable2Step.sol";

import {Proposer} from "./Proposer.sol";

/// @notice Proposer contract for `VotingEscrowDelegationProxy` contract
abstract contract TwoStepOwnableProposer is Proposer {
    /// @notice Add a `acceptOwnership` action to the proposal engine
    function acceptOwnership() external {
        bytes memory input = abi.encodePacked(Ownable2Step.acceptOwnership.selector);
        _addAction(input);
    }

    function _addAction(bytes memory _input) internal virtual {}
}
