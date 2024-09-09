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

import {ILiquidityGauge} from "balancer-labs/v2-interfaces/liquidity-mining/ILiquidityGauge.sol";

import {SafeMath} from "ve-silo/contracts/utils/SafeMath.sol";

import {IBalancerMinter} from "./interfaces/IBalancerMinter.sol";
import {IBalancerTokenAdmin} from "./interfaces/IBalancerTokenAdmin.sol";
import {ILMGetters, IGaugeController} from "./interfaces/ILMGetters.sol";
import {BalancerMinter} from "./BalancerMinter.sol";

contract MainnetBalancerMinter is IBalancerMinter, ILMGetters, BalancerMinter {
    using SafeMath for uint256;

    IBalancerTokenAdmin private immutable _tokenAdmin;
    IGaugeController private immutable _gaugeController;

    constructor(IBalancerTokenAdmin tokenAdmin, IGaugeController gaugeController)
        BalancerMinter(tokenAdmin.getBalancerToken(), "Silo Minter", "1")
    {
        _tokenAdmin = tokenAdmin;
        _gaugeController = gaugeController;
    }

    /// @inheritdoc ILMGetters
    function getBalancerTokenAdmin() external view override returns (IBalancerTokenAdmin) {
        return _tokenAdmin;
    }

    /// @inheritdoc ILMGetters
    function getGaugeController() external view override returns (IGaugeController) {
        return _gaugeController;
    }

    // Internal functions

    function _mintFor(address gauge, address user) internal override returns (uint256 tokensToMint) {
        tokensToMint = _updateGauge(gauge, user);
        _mint(user, tokensToMint);
    }

    function _mintForMany(address[] calldata gauges, address user) internal override returns (uint256 tokensToMint) {
        uint256 length = gauges.length;
        for (uint256 i = 0; i < length; ++i) {
            tokensToMint = tokensToMint.add(_updateGauge(gauges[i], user));
        }

        _mint(user, tokensToMint);
    }

    function _updateGauge(address gauge, address user) internal returns (uint256 tokensToMint) {
        require(_gaugeController.gauge_types(gauge) >= 0, "Gauge does not exist on Controller");

        ILiquidityGauge(gauge).user_checkpoint(user);
        uint256 totalMint = ILiquidityGauge(gauge).integrate_fraction(user);
        tokensToMint = totalMint.sub(minted(user, gauge));

        if (tokensToMint > 0) {
            _setMinted(user, gauge, totalMint);

            if (gauge != user) { // Stakeless gauge mints to itself. In this case, we will take a cut on L2
                tokensToMint = _collectFees(gauge, tokensToMint);
                _addMintedToUser(user, gauge, tokensToMint);
            }
        }
    }

    function _mint(address user, uint256 tokensToMint) internal override {
        if (tokensToMint > 0) {
            _tokenAdmin.mint(user, tokensToMint);
        }
    }
}
