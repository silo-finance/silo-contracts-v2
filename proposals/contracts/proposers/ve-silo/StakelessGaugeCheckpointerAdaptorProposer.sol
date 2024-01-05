// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {TwoStepOwnableProposer, Proposer} from "../../TwoStepOwnableProposer.sol";
import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";

/// @notice Proposer contract for `StakelessGaugeCheckpointerAdaptor` contract
contract StakelessGaugeCheckpointerAdaptorProposer is TwoStepOwnableProposer {
    // solhint-disable-next-line var-name-mixedcase
    address public immutable STAKELESS_GAUGE_CHECKPOINTER_ADAPTOR;

    /// @param _proposal The address of the proposal script (forge script where proposal logic is described)
    constructor(address _proposal) Proposer(_proposal) {
        STAKELESS_GAUGE_CHECKPOINTER_ADAPTOR = VeSiloDeployments.get(
            VeSiloContracts.STAKELESS_GAUGE_CHECKPOINTER_ADAPTOR,
            ChainsLib.chainAlias()
        );

        if (STAKELESS_GAUGE_CHECKPOINTER_ADAPTOR == address (0)) revert DeploymentNotFound(
            VeSiloContracts.STAKELESS_GAUGE_CHECKPOINTER_ADAPTOR,
            ChainsLib.chainAlias()
        );
    }

    function _addAction(bytes memory _input) internal override {
        _addAction({_target: STAKELESS_GAUGE_CHECKPOINTER_ADAPTOR, _value: 0, _input: _input});
    }
}
