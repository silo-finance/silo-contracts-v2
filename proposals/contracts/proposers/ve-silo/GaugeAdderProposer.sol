// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {Ownable2Step} from "openzeppelin5/access/Ownable2Step.sol";

import {Proposer} from "../../Proposer.sol";
import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";
import {IGaugeAdder} from "ve-silo/contracts/gauges/interfaces/IGaugeAdder.sol";
import {ILiquidityGaugeFactory} from "ve-silo/contracts/gauges/interfaces/ILiquidityGaugeFactory.sol";

/// @notice Proposer contract for `GaugeAdder` contract
contract GaugeAdderProposer is Proposer {
    // solhint-disable-next-line var-name-mixedcase
    address public immutable GAUGE_ADDER;

    /// @param _proposal The address of the proposal script (forge script where proposal logic is described)
    constructor(address _proposal) Proposer(_proposal) {
        GAUGE_ADDER = VeSiloDeployments.get(
            VeSiloContracts.GAUGE_ADDER,
            ChainsLib.chainAlias()
        );

        if (GAUGE_ADDER == address (0)) revert DeploymentNotFound(
            VeSiloContracts.GAUGE_ADDER,
            ChainsLib.chainAlias()
        );
    }

    /// @notice Add a `acceptOwnership` action to the proposal engine
    function acceptOwnership() external {
        bytes memory input = abi.encodePacked(Ownable2Step.acceptOwnership.selector);
        _addAction(input);
    }

    /// @notice Add a `addGaugeType` action to the proposal engine
    /// @param _gaugeType The type of the gauge to be added
    function addGaugeType(string memory _gaugeType) external {
        bytes memory input = abi.encodeCall(IGaugeAdder.addGaugeType, _gaugeType);
        _addAction(input);
    }

    /// @notice Add a `addGauge` action to the proposal engine
    /// @param _gauge The address of the gauge to be added
    /// @param _gaugeType The type of the gauge to be added
    function addGauge(address _gauge, string memory _gaugeType) external {
         bytes memory input = abi.encodeCall(IGaugeAdder.addGauge, (_gauge, _gaugeType));
        _addAction(input);
    }

    /// @notice Add a `setGaugeFactory` action to the proposal engine
    /// @param _factory The address of the gauge factory to be set
    function setGaugeFactory(address _factory, string memory _gaugeType) external {
         bytes memory input = abi.encodeCall(
            IGaugeAdder.setGaugeFactory,
            (ILiquidityGaugeFactory(_factory), _gaugeType)
        );

        _addAction(input);
    }

    function _addAction(bytes memory _input) internal {
        _addAction({_target: GAUGE_ADDER, _value: 0, _input: _input});
    }
}
