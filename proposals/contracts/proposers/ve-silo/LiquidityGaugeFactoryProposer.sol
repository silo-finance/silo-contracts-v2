// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {TwoStepOwnableProposer, Proposer} from "../../TwoStepOwnableProposer.sol";
import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";

/// @notice Proposer contract for `LiquidityGaugeFactory` contract
contract LiquidityGaugeFactoryProposer is TwoStepOwnableProposer {
    // solhint-disable-next-line var-name-mixedcase
    address public immutable LIQUIDITY_GAUGE_FACTORY;

    /// @param _proposal The address of the proposal script (forge script where proposal logic is described)
    constructor(address _proposal) Proposer(_proposal) {
        LIQUIDITY_GAUGE_FACTORY = VeSiloDeployments.get(
            VeSiloContracts.LIQUIDITY_GAUGE_FACTORY,
            ChainsLib.chainAlias()
        );

        if (LIQUIDITY_GAUGE_FACTORY == address (0)) revert DeploymentNotFound(
            VeSiloContracts.LIQUIDITY_GAUGE_FACTORY,
            ChainsLib.chainAlias()
        );
    }

    function _addAction(bytes memory _input) internal override {
        _addAction({_target: LIQUIDITY_GAUGE_FACTORY, _value: 0, _input: _input});
    }
}
