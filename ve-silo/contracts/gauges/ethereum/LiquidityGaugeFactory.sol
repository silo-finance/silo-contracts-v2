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

pragma solidity 0.8.24;

import {Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {ISiloLiquidityGauge} from "../interfaces/ISiloLiquidityGauge.sol";
import {FeesManager} from "../../silo-tokens-minter/FeesManager.sol";
import {BaseGaugeFactory} from "../BaseGaugeFactory.sol";

contract LiquidityGaugeFactory is BaseGaugeFactory, FeesManager {
    constructor(ISiloLiquidityGauge gauge) BaseGaugeFactory(address(gauge)) Ownable(msg.sender) {
        // solhint-disable-previous-line no-empty-blocks
    }

    /**
     * @notice Deploys a new gauge for a Balancer pool.
     * @dev As anyone can register arbitrary Balancer pools with the Vault,
     * it's impossible to prove onchain that `pool` is a "valid" deployment.
     *
     * Care must be taken to ensure that gauges deployed from this factory are
     * suitable before they are added to the GaugeController.
     *
     * It is possible to deploy multiple gauges for a single pool.
     * @param relativeWeightCap The relative weight cap for the created gauge
     * @param shareToken The address of the Silo share token
     * @return The address of the deployed gauge
     */
    function create(uint256 relativeWeightCap, address shareToken) external returns (address) {
        address gauge = _create();
        ISiloLiquidityGauge(gauge).initialize(relativeWeightCap, shareToken);
        return gauge;
    }
}
