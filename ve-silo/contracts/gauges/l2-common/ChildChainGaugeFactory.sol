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

import {IChildChainGauge} from "balancer-labs/v2-interfaces/liquidity-mining/IChildChainGauge.sol";
import {Version} from "../_common/Version.sol";
import {FeesManager} from "../../silo-tokens-minter/FeesManager.sol";
import {BaseGaugeFactory} from "../BaseGaugeFactory.sol";

contract ChildChainGaugeFactory is Version, BaseGaugeFactory, FeesManager {
    string private _productVersion;

    constructor(
        IChildChainGauge gaugeImplementation,
        string memory factoryVersion,
        string memory productVersion
    ) Version(factoryVersion) BaseGaugeFactory(address(gaugeImplementation)) Ownable(msg.sender) {
        require(
            keccak256(abi.encodePacked(gaugeImplementation.version())) == keccak256(abi.encodePacked(productVersion)),
            "VERSION_MISMATCH"
        );
        _productVersion = productVersion;
    }

    /**
     * @notice Returns a JSON representation of the deployed gauge version containing name, version number and task ID.
     *
     * @dev This value will only be updated at factory creation time.
     */
    function getProductVersion() public view returns (string memory) {
        return _productVersion;
    }

    /**
     * @notice Deploys a new gauge for a ERC-20 balances handler (Silo shares token)
     *
     * It is possible to deploy multiple gauges for a single pool.
     * @param shareToken The address of the Silo share token
     * @return The address of the deployed gauge
     */
    function create(address shareToken) external returns (address) { //solhint-disable-line ordering
        address gauge = _create();
        IChildChainGauge(gauge).initialize(shareToken, getProductVersion());
        return gauge;
    }
}
