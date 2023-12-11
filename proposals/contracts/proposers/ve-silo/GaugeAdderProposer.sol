// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {Ownable2Step} from "openzeppelin-contracts/access/Ownable2Step.sol";

import {Proposer} from "../../Proposer.sol";
import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";
import {IGaugeAdder} from "ve-silo/contracts/gauges/interfaces/IGaugeAdder.sol";
import {ILiquidityGaugeFactory} from "ve-silo/contracts/gauges/interfaces/ILiquidityGaugeFactory.sol";

contract GaugeAdderProposer is Proposer {
    // solhint-disable-next-line var-name-mixedcase
    address public immutable GAUGE_ADDER;

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

    function acceptOwnership() external {
        bytes memory input = abi.encodePacked(Ownable2Step.acceptOwnership.selector);
        _addAction(input);
    }

    function addGaugeType(string memory _gaugeType) external {
        bytes memory input = abi.encodeCall(IGaugeAdder.addGaugeType, _gaugeType);
        _addAction(input);
    }

    function addGauge(address _gauge, string memory _gaugeType) external {
         bytes memory input = abi.encodeCall(IGaugeAdder.addGauge, (_gauge, _gaugeType));
        _addAction(input);
    }

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
