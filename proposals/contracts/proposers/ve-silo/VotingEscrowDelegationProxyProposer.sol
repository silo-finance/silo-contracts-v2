// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {TwoStepOwnableProposer, Proposer} from "../../TwoStepOwnableProposer.sol";
import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";

/// @notice Proposer contract for `VotingEscrowDelegationProxy` contract
contract VotingEscrowDelegationProxyProposer is TwoStepOwnableProposer {
    // solhint-disable-next-line var-name-mixedcase
    address public immutable VOTING_ESCRW_DELEGATION_PROXY;

    /// @param _proposal The address of the proposal script (forge script where proposal logic is described)
    constructor(address _proposal) Proposer(_proposal) {
        VOTING_ESCRW_DELEGATION_PROXY = VeSiloDeployments.get(
            VeSiloContracts.VOTING_ESCROW_DELEGATION_PROXY,
            ChainsLib.chainAlias()
        );

        if (VOTING_ESCRW_DELEGATION_PROXY == address (0)) revert DeploymentNotFound(
            VeSiloContracts.VOTING_ESCROW_DELEGATION_PROXY,
            ChainsLib.chainAlias()
        );
    }

    function _addAction(bytes memory _input) internal override {
        _addAction({_target: VOTING_ESCRW_DELEGATION_PROXY, _value: 0, _input: _input});
    }
}
