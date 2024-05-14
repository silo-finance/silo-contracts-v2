// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {TwoStepOwnableProposer, Proposer} from "../../TwoStepOwnableProposer.sol";
import {SiloCoreContracts, SiloCoreDeployments} from "silo-core/common/SiloCoreContracts.sol";

/// @notice Proposer contract for `SiloFactory` contract
contract SiloFactoryProposer is TwoStepOwnableProposer {
    // solhint-disable-next-line var-name-mixedcase
    address public immutable SILO_FACTORY;

    /// @param _proposal The address of the proposal script (forge script where proposal logic is described)
    constructor(address _proposal) Proposer(_proposal) {
        SILO_FACTORY = SiloCoreDeployments.get(
            SiloCoreContracts.SILO_FACTORY,
            ChainsLib.chainAlias()
        );

        if (SILO_FACTORY == address (0)) revert DeploymentNotFound(
            SiloCoreContracts.SILO_FACTORY,
            ChainsLib.chainAlias()
        );
    }

    function _addAction(bytes memory _input) internal override {
        _addAction({_target: SILO_FACTORY, _value: 0, _input: _input});
    }
}
