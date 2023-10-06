// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {Ownable2Step} from "openzeppelin-contracts/access/Ownable2Step.sol";

import {BaseGaugeFactory} from "../BaseGaugeFactory.sol";
import {CCIPGauge} from "./CCIPGauge.sol";

abstract contract CCIPGaugeFactory is BaseGaugeFactory, Ownable2Step {
    address public checkpointer;

    constructor(address _checkpointer, address _gaugeImplementation)
        BaseGaugeFactory(_gaugeImplementation)
    {
        checkpointer = _checkpointer;
    }

    /**
     * @notice Deploys a new gauge which bridges all of its BAL allowance to a single recipient on Arbitrum.
     * @dev Care must be taken to ensure that gauges deployed from this factory are
     * suitable before they are added to the GaugeController.
     * @param recipient The address to receive BAL minted from the gauge
     * @param relativeWeightCap The relative weight cap for the created gauge
     * @return The address of the deployed gauge
     */
    function create(address recipient, uint256 relativeWeightCap) external returns (address) {
        address gauge = _create();

        CCIPGauge(gauge).initialize(recipient, relativeWeightCap, checkpointer);

        return gauge;
    }
}
