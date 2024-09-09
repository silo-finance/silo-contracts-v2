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

import {Ownable2Step} from "openzeppelin5/access/Ownable2Step.sol";

import {IFeesManager} from "./interfaces/IFeesManager.sol";

abstract contract FeesManager is IFeesManager, Ownable2Step {
    /// @dev max baisis points (30%)
    uint256 public constant BPS_MAX = 3e3;

    uint128 public daoFee;
    uint128 public deployerFee;

    /// @inheritdoc IFeesManager
    function setFees(
        uint256 _daoFee,
        uint256 _deployerFee
    )
        external
        onlyOwner
    {
        if (_daoFee + _deployerFee > BPS_MAX) revert OverallFee();

        daoFee = uint128(_daoFee);
        deployerFee = uint128(_deployerFee);

        emit FeesUpdate(daoFee, deployerFee);
    }

    /// @inheritdoc IFeesManager
    function getFees() external view returns (uint256, uint256) {
        return (daoFee, deployerFee);
    }
}
