// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {IBeacon} from "openzeppelin5/proxy/beacon/IBeacon.sol";
import {BeaconProxy} from "openzeppelin5/proxy/beacon/BeaconProxy.sol";

import {BaseGaugeFactory} from "../BaseGaugeFactory.sol";
import {CCIPGauge} from "./CCIPGauge.sol";

abstract contract CCIPGaugeFactory is BaseGaugeFactory, Ownable2Step {
    // solhint-disable-next-line var-name-mixedcase
    IBeacon public immutable BEACON;
    address public checkpointer;

    constructor(address _beacon, address _checkpointer)
        Ownable(msg.sender)
        BaseGaugeFactory(address(0))
    {
        checkpointer = _checkpointer;
        BEACON = IBeacon(_beacon);
    }

    /**
     * @notice Deploys a new gauge which bridges all of its BAL allowance to a single recipient on Arbitrum.
     * @dev Care must be taken to ensure that gauges deployed from this factory are
     * suitable before they are added to the GaugeController.
     * @param recipient The address to receive BAL minted from the gauge
     * @param relativeWeightCap The relative weight cap for the created gauge
     * @param destinationChain The destination chain for the gauge
     * @return The address of the deployed gauge
     */
    function create(address recipient, uint256 relativeWeightCap, uint64 destinationChain) external returns (address) {
        address gauge = _create();

        CCIPGauge(gauge).initialize(recipient, relativeWeightCap, checkpointer, destinationChain);

        return gauge;
    }

    /**
     * @return The address of the gauge implementation.
     */
    function getGaugeImplementation() public override view returns (address) {
        return BEACON.implementation();
    }

    /**
     * @dev Deploy a proxy.
     */
    function _createGauge() internal override returns (address) {
        return address(new BeaconProxy(address(BEACON), ""));
    }
}
