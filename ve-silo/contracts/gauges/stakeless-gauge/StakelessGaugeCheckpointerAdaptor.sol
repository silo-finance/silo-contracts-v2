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

import {Address} from "openzeppelin5/utils/Address.sol";
import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {IStakelessGauge} from "../interfaces/IStakelessGauge.sol";
import {IStakelessGaugeCheckpointerAdaptor} from "../interfaces/IStakelessGaugeCheckpointerAdaptor.sol";

contract StakelessGaugeCheckpointerAdaptor is Ownable2Step, IStakelessGaugeCheckpointerAdaptor {
    // solhint-disable-next-line var-name-mixedcase
    address public immutable LINK;
    address public checkpointer;

    event CheckpointerUpdated(address checkpointer);

    error TheSameCheckpointer();
    error OnlyCheckpointer();

    constructor(address _link) Ownable(msg.sender) {
        LINK = _link;
    }

    /// @notice Receive fn to be able to receive ether leftover from the gauge after checkpoint.
    receive() external payable {}

    /// @inheritdoc IStakelessGaugeCheckpointerAdaptor
    function checkpoint(address gauge) external payable returns (bool result) {
        if (msg.sender != checkpointer) revert OnlyCheckpointer();

        result = IStakelessGauge(gauge).checkpoint{ value: msg.value }();

        _returnLeftoverIfAny();
    }

    /// @inheritdoc IStakelessGaugeCheckpointerAdaptor
    function setStakelessGaugeCheckpointer(address newCheckpointer) external onlyOwner {
        if (checkpointer == newCheckpointer) revert TheSameCheckpointer();

        checkpointer = newCheckpointer;

        emit CheckpointerUpdated(checkpointer);
    }

    /// @dev Ensure that the contract returns any leftover ether or LINK to the sender
    function _returnLeftoverIfAny() internal {
        uint256 remainingBalance = address(this).balance;

        if (remainingBalance > 0) {
            Address.sendValue(payable(msg.sender), remainingBalance);
        }

        uint256 remainingLINKBalance = IERC20(LINK).balanceOf(address(this));

        if (remainingLINKBalance > 0) {
            IERC20(LINK).transfer(msg.sender, remainingLINKBalance);
        }
    }
}
