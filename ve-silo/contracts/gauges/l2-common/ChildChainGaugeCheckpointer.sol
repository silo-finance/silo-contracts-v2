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

import {IChildChainGauge} from "balancer-labs/v2-interfaces/liquidity-mining/IChildChainGauge.sol";
import {ILiquidityGaugeFactory} from "balancer-labs/v2-interfaces/liquidity-mining/ILiquidityGaugeFactory.sol";

import {IL2LayerZeroDelegation} from "balancer-labs/v2-interfaces/liquidity-mining/IL2LayerZeroDelegation.sol";

import {IChildChainGaugeRegistry} from "../interfaces/IChildChainGaugeRegistry.sol";

/**
 * @title ChildChainGaugeCheckpointer
 * @notice Checkpointer for all child chain gauges.
 * This contract calls `user_checkpoint` function on every child chain gauge during onVeBalBridged callback.
 */
contract ChildChainGaugeCheckpointer is IL2LayerZeroDelegation {
    IChildChainGaugeRegistry private immutable _childChainGaugeRegistry;

    constructor(IChildChainGaugeRegistry childChainGaugeRegistry) {
        _childChainGaugeRegistry = childChainGaugeRegistry;
    }

    /// @inheritdoc IL2LayerZeroDelegation
    function onVeBalBridged(address user) external override {
        uint256 totalGauges = _childChainGaugeRegistry.totalGauges();
        IChildChainGauge[] memory gauges = _childChainGaugeRegistry.getGauges(0, totalGauges);
        for (uint256 i = 0; i < totalGauges; i++) {
            gauges[i].user_checkpoint(user);
        }
    }

    /// @inheritdoc IL2LayerZeroDelegation
    function onVeBalSupplyUpdate() external override {
        // solhint-disable-previous-line no-empty-blocks
    }
}
