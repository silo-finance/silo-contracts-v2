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

pragma solidity >=0.5.0;

/// @notice Manage DAO and deployer fees for gauges
interface IFeesManager {
    /// @dev Emit when fee updated
    /// @param daoFee A new DAO fee
    /// @param deployerFee A new deployer fee
    event FeesUpdate(uint256 daoFee, uint256 deployerFee);

    /// @dev Revert if the DAO plus the Gauge fee is more than 100%
    error OverallFee();

    /// @dev Zero fees are acceptable
    /// @param _daoFee A new DAO fee
    /// @param _deployerFee A new deployer fee
    function setFees(uint256 _daoFee, uint256 _deployerFee) external;

    /// @return daoFee DAO fee
    /// @return deployerFee Deployer fee
    function getFees() external view returns (uint256 daoFee, uint256 deployerFee);
}
