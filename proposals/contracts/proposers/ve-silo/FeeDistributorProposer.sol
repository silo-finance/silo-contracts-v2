// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {TwoStepOwnableProposer, Proposer} from "../../TwoStepOwnableProposer.sol";
import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";

/// @notice Proposer contract for `FeeDistributor` contract
contract FeeDistributorProposer is TwoStepOwnableProposer {
    // solhint-disable-next-line var-name-mixedcase
    address public immutable FEE_DISTRIBUTOR;

    /// @param _proposal The address of the proposal script (forge script where proposal logic is described)
    constructor(address _proposal) Proposer(_proposal) {
        FEE_DISTRIBUTOR = VeSiloDeployments.get(
            VeSiloContracts.FEE_DISTRIBUTOR,
            ChainsLib.chainAlias()
        );

        if (FEE_DISTRIBUTOR == address (0)) revert DeploymentNotFound(
            VeSiloContracts.FEE_DISTRIBUTOR,
            ChainsLib.chainAlias()
        );
    }

    function _addAction(bytes memory _input) internal override {
        _addAction({_target: FEE_DISTRIBUTOR, _value: 0, _input: _input});
    }
}
