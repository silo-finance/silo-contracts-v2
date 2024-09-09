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

import {ISmartWalletChecker} from "balancer-labs/v2-interfaces/liquidity-mining/ISmartWalletChecker.sol";

import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {EnumerableSet} from "openzeppelin5/utils/structs/EnumerableSet.sol";

// solhint-disable ordering

contract SmartWalletChecker is ISmartWalletChecker, Ownable2Step {
    using EnumerableSet for EnumerableSet.AddressSet;

    event ContractAddressAdded(address contractAddress);
    event ContractAddressRemoved(address contractAddress);

    EnumerableSet.AddressSet private _allowlistedAddresses;

    constructor(address[] memory initialAllowedAddresses) Ownable(msg.sender) {
        uint256 addressesLength = initialAllowedAddresses.length;
        for (uint256 i = 0; i < addressesLength; ++i) {
            _allowlistAddress(initialAllowedAddresses[i]);
        }
    }

    function check(address contractAddress) external view override returns (bool) {
        return _allowlistedAddresses.contains(contractAddress);
    }

    function getAllowlistedAddress(uint256 index) external view returns (address) {
        return _allowlistedAddresses.at(index);
    }

    function getAllowlistedAddressesLength() external view returns (uint256) {
        return _allowlistedAddresses.length();
    }

    function allowlistAddress(address contractAddress) external onlyOwner {
        _allowlistAddress(contractAddress);
    }

    function denylistAddress(address contractAddress) external onlyOwner {
        require(_allowlistedAddresses.remove(contractAddress), "Address is not allowlisted");
        emit ContractAddressRemoved(contractAddress);
    }

    // Internal functions

    function _allowlistAddress(address contractAddress) internal {
        require(_allowlistedAddresses.add(contractAddress), "Address already allowlisted");
        emit ContractAddressAdded(contractAddress);
    }
}
