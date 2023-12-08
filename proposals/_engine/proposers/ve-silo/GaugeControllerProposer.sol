// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {Proposer} from "../../Proposer.sol";
import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";
import {IGaugeController} from "ve-silo/contracts/gauges/interfaces/IGaugeController.sol";

contract GaugeControllerProposer is Proposer {
    address private immutable _GAUGE_CONTROLLER;

    constructor() {
        _GAUGE_CONTROLLER = VeSiloDeployments.get(
            VeSiloContracts.GAUGE_CONTROLLER,
            ChainsLib.chainAlias()
        );

        if (_GAUGE_CONTROLLER == address (0)) revert DeploymentNotFound(
            VeSiloContracts.GAUGE_CONTROLLER,
            ChainsLib.chainAlias()
        );
    }

    function add_type(string memory _gaugeType) external {
        bytes memory data = abi.encodeWithSignature("add_type(string,uint256)", _gaugeType, 1e18);
        _addAction(data);
    }

    function set_gauge_adder(address _gaugeAdder) external {
        bytes memory data = abi.encodeCall(IGaugeController.set_gauge_adder, _gaugeAdder);
        _addAction(data);
    }

    function _addAction(bytes memory _data) internal {
        PROPOSAL_ENGINE.addAction({_target: _GAUGE_CONTROLLER, _data: _data});
    }
}
