// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {TwoStepOwnableProposer, Proposer} from "../../TwoStepOwnableProposer.sol";
import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";
import {ICCIPGaugeCheckpointer} from "ve-silo/contracts/gauges/interfaces/ICCIPGaugeCheckpointer.sol";
import {ICCIPGauge} from "ve-silo/contracts/gauges/interfaces/ICCIPGauge.sol";

/// @notice Proposer contract for `CCIPGaugeCheckpointer` contract
contract CCIPGaugeCheckpointerProposer is TwoStepOwnableProposer {
    // solhint-disable-next-line var-name-mixedcase
    address public immutable CHECKPOINTER;

    /// @param _proposal The address of the proposal script (forge script where proposal logic is described)
    constructor(address _proposal) Proposer(_proposal) {
        CHECKPOINTER = VeSiloDeployments.get(
            VeSiloContracts.CCIP_GAUGE_CHECKPOINTER,
            ChainsLib.chainAlias()
        );

        if (CHECKPOINTER == address (0)) revert DeploymentNotFound(
            VeSiloContracts.CCIP_GAUGE_CHECKPOINTER,
            ChainsLib.chainAlias()
        );
    }

    /// @notice Adds gauges to the checkpointer
    /// @param gaugeType The type of the gauge
    /// @param gauges The array of gauges to add
    function addGauges(string calldata gaugeType, ICCIPGauge[] calldata gauges) external {
        bytes memory input = abi.encodeCall(ICCIPGaugeCheckpointer.addGauges, (gaugeType, gauges));
        _addAction(input);
    }

    function _addAction(bytes memory _input) internal override {
        _addAction({_target: CHECKPOINTER, _value: 0, _input: _input});
    }
}
