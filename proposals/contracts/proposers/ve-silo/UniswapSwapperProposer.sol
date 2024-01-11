// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {TwoStepOwnableProposer, Proposer} from "../../TwoStepOwnableProposer.sol";
import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";

/// @notice Proposer contract for `UniswapSwapperProposer` contract
contract UniswapSwapperProposer is TwoStepOwnableProposer {
    // solhint-disable-next-line var-name-mixedcase
    address public immutable SWAPPER;

    /// @param _proposal The address of the proposal script (forge script where proposal logic is described)
    constructor(address _proposal) Proposer(_proposal) {
        SWAPPER = VeSiloDeployments.get(
            VeSiloContracts.UNISWAP_SWAPPER,
            ChainsLib.chainAlias()
        );

        if (SWAPPER == address (0)) revert DeploymentNotFound(
            VeSiloContracts.UNISWAP_SWAPPER,
            ChainsLib.chainAlias()
        );
    }

    function _addAction(bytes memory _input) internal override {
        _addAction({_target: SWAPPER, _value: 0, _input: _input});
    }
}
