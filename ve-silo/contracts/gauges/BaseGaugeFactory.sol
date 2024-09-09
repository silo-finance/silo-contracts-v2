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

import {ILiquidityGaugeFactory} from "balancer-labs/v2-interfaces/liquidity-mining/ILiquidityGaugeFactory.sol";

import {Clones} from "openzeppelin5/proxy/Clones.sol";

// solhint-disable ordering

abstract contract BaseGaugeFactory is ILiquidityGaugeFactory {
    address private _gaugeImplementation;

    mapping(address => bool) private _isGaugeFromFactory;

    event GaugeCreated(address indexed gauge);

    constructor(address gaugeImplementation) {
        _gaugeImplementation = gaugeImplementation;
    }

    /**
     * @notice Returns the address of the implementation used for gauge deployments.
     */
    function getGaugeImplementation() public virtual view returns (address) {
        return _gaugeImplementation;
    }

    /**
     * @notice Returns true if `gauge` was created by this factory.
     */
    function isGaugeFromFactory(address gauge) external view override returns (bool) {
        return _isGaugeFromFactory[gauge];
    }

    /**
     * @dev Deploys a new gauge as a proxy of the implementation in storage.
     * The deployed gauge must be initialized by the caller method.
     * @return The address of the deployed gauge
     */
    function _create() internal returns (address) {
        address gauge = _createGauge();

        _isGaugeFromFactory[gauge] = true;
        emit GaugeCreated(gauge);

        return gauge;
    }

    /**
     * @dev Clone the gauge implementation.
     * Can be overridden to provide custom logic for the gauge deployment.
     */
    function _createGauge() internal virtual returns (address) {
        return Clones.clone(_gaugeImplementation);
    }
}
