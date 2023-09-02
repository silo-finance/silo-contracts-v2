// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity 0.8.19;

import {Ownable2Step} from "openzeppelin-contracts/access/Ownable2Step.sol";

import {BaseGaugeFactory} from "../BaseGaugeFactory.sol";

import {ArbitrumRootGauge, IGatewayRouter, IMainnetBalancerMinter, IArbitrumFeeProvider}
    from "./ArbitrumRootGauge.sol";

contract ArbitrumRootGaugeFactory is IArbitrumFeeProvider, BaseGaugeFactory, Ownable2Step {
    uint64 private _gasLimit;
    uint64 private _gasPrice;
    uint64 private _maxSubmissionCost;

    address private _checkpointer;

    event ArbitrumFeesModified(uint256 gasLimit, uint256 gasPrice, uint256 maxSubmissionCost);

    constructor(
        IMainnetBalancerMinter minter,
        IGatewayRouter gatewayRouter,
        uint64 gasLimit,
        uint64 gasPrice,
        uint64 maxSubmissionCost,
        address checkpointer
    ) BaseGaugeFactory(address(new ArbitrumRootGauge(minter, gatewayRouter))) {
        _gasLimit = gasLimit;
        _gasPrice = gasPrice;
        _maxSubmissionCost = maxSubmissionCost;
        _checkpointer = checkpointer;
    }

    // solhint-disable ordering

    /**
     * @notice Set the fees for the Arbitrum side of the bridging transaction
     */
    function getArbitrumFees()
        external
        view
        override
        returns (
            uint256 gasLimit,
            uint256 gasPrice,
            uint256 maxSubmissionCost
        )
    {
        gasLimit = _gasLimit;
        gasPrice = _gasPrice;
        maxSubmissionCost = _maxSubmissionCost;
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
        ArbitrumRootGauge(gauge).initialize(recipient, relativeWeightCap, _checkpointer);
        return gauge;
    }

    /**
     * @notice Set the fees for the Arbitrum side of the bridging transaction
     */
    function setArbitrumFees(
        uint64 gasLimit,
        uint64 gasPrice,
        uint64 maxSubmissionCost
    ) external override onlyOwner {
        _gasLimit = gasLimit;
        _gasPrice = gasPrice;
        _maxSubmissionCost = maxSubmissionCost;
        emit ArbitrumFeesModified(gasLimit, gasPrice, maxSubmissionCost);
    }
}
