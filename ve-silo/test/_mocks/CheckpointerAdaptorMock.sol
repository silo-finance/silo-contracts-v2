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

contract CheckpointerAdaptorMock {
    receive() external payable {}

    function checkpoint(address) external payable returns (bool result) {
        // Send back any leftover ETH to the caller if there is an existing balance in the contract.
        uint256 remainingBalance = address(this).balance;
        if (remainingBalance > 0) {
            Address.sendValue(payable(msg.sender), remainingBalance);
        }

        result = true;
    }
}
