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

pragma solidity 0.8.21;

import {Address} from "openzeppelin-contracts/utils/Address.sol";
import {Ownable2Step} from "openzeppelin-contracts/access/Ownable2Step.sol";

import {IStakelessGauge} from "../interfaces/IStakelessGauge.sol";
import {IStakelessGaugeCheckpointerAdaptor} from "../interfaces/IStakelessGaugeCheckpointerAdaptor.sol";

contract StakelessGaugeCheckpointerAdaptor is Ownable2Step, IStakelessGaugeCheckpointerAdaptor {
    address public checkpointer;

    event CheckpointerUpdated(address checkpointer);

    error TheSameCheckpointer();
    error OnlyCheckpointer();

    /// @inheritdoc IStakelessGaugeCheckpointerAdaptor
    function checkpoint(address gauge) external payable returns (bool result) {
        if (msg.sender != checkpointer) revert OnlyCheckpointer();

        result = IStakelessGauge(gauge).checkpoint{ value: msg.value }();

        // Send back any leftover ETH to the caller if there is an existing balance in the contract.
        uint256 remainingBalance = address(this).balance;
        if (remainingBalance > 0) {
            Address.sendValue(payable(msg.sender), remainingBalance);
        }
    }

    /// @inheritdoc IStakelessGaugeCheckpointerAdaptor
    function setStakelessGaugeCheckpointer(address newCheckpointer) external onlyOwner {
        if (checkpointer == newCheckpointer) revert TheSameCheckpointer();

        checkpointer = newCheckpointer;

        emit CheckpointerUpdated(checkpointer);
    }
}
