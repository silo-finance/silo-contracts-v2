// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {TwoStepOwnableProposer, Proposer} from "../../TwoStepOwnableProposer.sol";
import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";

/// @notice Proposer contract for `VeSiloDelegatorViaCCIP` contract
contract VeSiloDelegatorViaCCIPProposer is TwoStepOwnableProposer {
    // solhint-disable-next-line var-name-mixedcase
    address public immutable VESILO_DELEGATOR;

    /// @param _proposal The address of the proposal script (forge script where proposal logic is described)
    constructor(address _proposal) Proposer(_proposal) {
        VESILO_DELEGATOR = VeSiloDeployments.get(
            VeSiloContracts.VE_SILO_DELEGATOR_VIA_CCIP,
            ChainsLib.chainAlias()
        );

        if (VESILO_DELEGATOR == address (0)) revert DeploymentNotFound(
            VeSiloContracts.VE_SILO_DELEGATOR_VIA_CCIP,
            ChainsLib.chainAlias()
        );
    }

    function _addAction(bytes memory _input) internal override {
        _addAction({_target: VESILO_DELEGATOR, _value: 0, _input: _input});
    }
}
