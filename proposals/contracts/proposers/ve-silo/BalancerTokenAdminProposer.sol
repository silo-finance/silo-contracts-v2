// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {TwoStepOwnableProposer, Proposer} from "../../TwoStepOwnableProposer.sol";
import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";
import {IBalancerTokenAdmin} from "ve-silo/contracts/silo-tokens-minter/interfaces/IBalancerTokenAdmin.sol";

/// @notice Proposer contract for `BalancerTokenAdmin` contract
contract BalancerTokenAdminProposer is TwoStepOwnableProposer {
    // solhint-disable-next-line var-name-mixedcase
    address public immutable BALANCER_TOKEN_ADMIN;

    /// @param _proposal The address of the proposal script (forge script where proposal logic is described)
    constructor(address _proposal) Proposer(_proposal) {
        BALANCER_TOKEN_ADMIN = VeSiloDeployments.get(
            VeSiloContracts.BALANCER_TOKEN_ADMIN,
            ChainsLib.chainAlias()
        );

        if (BALANCER_TOKEN_ADMIN == address (0)) revert DeploymentNotFound(
            VeSiloContracts.BALANCER_TOKEN_ADMIN,
            ChainsLib.chainAlias()
        );
    }

    /// @notice Activates the Balancer Token Admin
    function activate() external {
        bytes memory input = abi.encodeWithSelector(IBalancerTokenAdmin.activate.selector);
        _addAction(input);
    }

    function _addAction(bytes memory _input) internal override {
        _addAction({_target: BALANCER_TOKEN_ADMIN, _value: 0, _input: _input});
    }
}
