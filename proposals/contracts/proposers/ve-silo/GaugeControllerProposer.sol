// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {Proposer} from "../../Proposer.sol";
import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";
import {IGaugeController} from "ve-silo/contracts/gauges/interfaces/IGaugeController.sol";

/// @notice Proposer contract for `GaugeController` contract
contract GaugeControllerProposer is Proposer {
    // solhint-disable-next-line var-name-mixedcase
    address public immutable GAUGE_CONTROLLER;

    /// @param _proposal The address of the proposal script (forge script where proposal logic is described)
    constructor(address _proposal) Proposer(_proposal) {
        GAUGE_CONTROLLER = VeSiloDeployments.get(
            VeSiloContracts.GAUGE_CONTROLLER,
            ChainsLib.chainAlias()
        );

        if (GAUGE_CONTROLLER == address (0)) revert DeploymentNotFound(
            VeSiloContracts.GAUGE_CONTROLLER,
            ChainsLib.chainAlias()
        );
    }

    /// @notice Add a `add_type` action to the proposal engine
    /// @param _gaugeType The type of the gauge to be added
    // solhint-disable-next-line func-name-mixedcase
    function add_type(string memory _gaugeType) external {
        bytes memory input = abi.encodeWithSignature("add_type(string,uint256)", _gaugeType, 1e18);
        _addAction(input);
    }

    /// @notice Add a `set_gauge_adder` action to the proposal engine
    /// @param _gaugeAdder The address of the gauge adder to be set
    // solhint-disable-next-line func-name-mixedcase
    function set_gauge_adder(address _gaugeAdder) external {
        bytes memory input = abi.encodeCall(IGaugeController.set_gauge_adder, _gaugeAdder);
        _addAction(input);
    }

    /// @notice Add a `change_type_weight` action to the proposal engine
    /// @param _gaugeType The type of the gauge to be changed
    /// @param _weight The weight to be set
    // solhint-disable-next-line func-name-mixedcase
    function change_type_weight(int128 _gaugeType, uint256 _weight) external {
        bytes memory input = abi.encodeCall(IGaugeController.change_type_weight, (_gaugeType, _weight));
        _addAction(input);
    }

    /// @notice Add a `change_gauge_weight` action to the proposal engine
    /// @param _gauge The address of the gauge for which the weight is to be set
    /// @param _weight The weight to be set
    // solhint-disable-next-line func-name-mixedcase
    function change_gauge_weight(address _gauge, uint256 _weight) external {
        bytes memory input = abi.encodeCall(IGaugeController.change_gauge_weight, (_gauge, _weight));
        _addAction(input);
    }

    function _addAction(bytes memory _input) internal {
        _addAction({_target: GAUGE_CONTROLLER, _value: 0, _input: _input});
    }
}
