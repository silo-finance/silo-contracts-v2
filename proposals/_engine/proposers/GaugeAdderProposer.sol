// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {Proposer} from "../Proposer.sol";
import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";
import {IGaugeAdder} from "ve-silo/contracts/gauges/interfaces/IGaugeAdder.sol";

contract GaugeAdderProposer is Proposer {
    address private _gaugeAdder;

    constructor() {
        _gaugeAdder = VeSiloDeployments.get(
            VeSiloContracts.GAUGE_ADDER,
            ChainsLib.chainAlias()
        );

        if (_gaugeAdder == address (0)) revert DeploymentNotFound(
            VeSiloContracts.GAUGE_ADDER,
            ChainsLib.chainAlias()
        );
    }

    function addGaugeType(string memory _gaugeType) external {
        bytes memory data = abi.encodeCall(IGaugeAdder.addGaugeType, _gaugeType);

        PROPOSAL_ENGINE.addAction({
            _target: _gaugeAdder,
            _value: 0,
            _data: data
        });
    }

    function addGauge(address _gauge, string memory _gaugeType) external {
         bytes memory data = abi.encodeCall(IGaugeAdder.addGauge, (_gauge, _gaugeType));

        PROPOSAL_ENGINE.addAction({
            _target: _gaugeAdder,
            _value: 0,
            _data: data
        });
    }
}
