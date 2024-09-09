// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {TwoStepOwnableProposer, Proposer} from "../../TwoStepOwnableProposer.sol";
import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";

/// @notice Proposer contract for `SmartWalletChecker` contract
contract SmartWalletCheckerProposer is TwoStepOwnableProposer {
    // solhint-disable-next-line var-name-mixedcase
    address public immutable SMART_WALLET_CHECKER;

    /// @param _proposal The address of the proposal script (forge script where proposal logic is described)
    constructor(address _proposal) Proposer(_proposal) {
        SMART_WALLET_CHECKER = VeSiloDeployments.get(
            VeSiloContracts.SMART_WALLET_CHECKER,
            ChainsLib.chainAlias()
        );

        if (SMART_WALLET_CHECKER == address (0)) revert DeploymentNotFound(
            VeSiloContracts.SMART_WALLET_CHECKER,
            ChainsLib.chainAlias()
        );
    }

    function _addAction(bytes memory _input) internal override {
        _addAction({_target: SMART_WALLET_CHECKER, _value: 0, _input: _input});
    }
}
