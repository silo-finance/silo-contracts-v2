// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {Ownable2Step} from "openzeppelin-contracts/access/Ownable2Step.sol";

import {Proposer} from "../../Proposer.sol";
import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";
import {IGaugeAdder} from "ve-silo/contracts/gauges/interfaces/IGaugeAdder.sol";
import {ILiquidityGaugeFactory} from "ve-silo/contracts/gauges/interfaces/ILiquidityGaugeFactory.sol";

contract GaugeAdderProposer is Proposer {
    address public immutable _GAUGE_ADDER;

    constructor() {
        _GAUGE_ADDER = VeSiloDeployments.get(
            VeSiloContracts.GAUGE_ADDER,
            ChainsLib.chainAlias()
        );

        if (_GAUGE_ADDER == address (0)) revert DeploymentNotFound(
            VeSiloContracts.GAUGE_ADDER,
            ChainsLib.chainAlias()
        );
    }

    function acceptOwnership() external {
        bytes memory data = abi.encodePacked(Ownable2Step.acceptOwnership.selector);
        _addAction(data);
    }

    function addGaugeType(string memory _gaugeType) external {
        bytes memory data = abi.encodeCall(IGaugeAdder.addGaugeType, _gaugeType);
        _addAction(data);
    }

    function addGauge(address _gauge, string memory _gaugeType) external {
         bytes memory data = abi.encodeCall(IGaugeAdder.addGauge, (_gauge, _gaugeType));
        _addAction(data);
    }

    function setGaugeFactory(address _factory, string memory _gaugeType) external {
         bytes memory data = abi.encodeCall(
            IGaugeAdder.setGaugeFactory,
            (ILiquidityGaugeFactory(_factory), _gaugeType)
        );

        _addAction(data);
    }

    function _addAction(bytes memory _data) internal {
        PROPOSAL_ENGINE.addAction({_target: _GAUGE_ADDER, _data: _data});
    }
}
