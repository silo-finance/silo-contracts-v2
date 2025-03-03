// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";
import {UtilsLib} from "morpho-blue/libraries/UtilsLib.sol";

import {ErrorsLib} from "./ErrorsLib.sol";
import {EventsLib} from "./EventsLib.sol";

library SiloVaultActionsLib {
    function setIsAllocator(
        address _newAllocator,
        bool _newIsAllocator,
        mapping(address => bool) storage _isAllocator
    ) external {
        if (_isAllocator[_newAllocator] == _newIsAllocator) revert ErrorsLib.AlreadySet();

        _isAllocator[_newAllocator] = _newIsAllocator;

        emit EventsLib.SetIsAllocator(_newAllocator, _newIsAllocator);
    }

    /// @dev Simulates a withdraw of `assets` from ERC4626 vault.
    /// @return The remaining assets to be withdrawn.
    function simulateWithdrawERC4626(
        uint256 _assets,
        IERC4626[] storage _withdrawQueue
    ) external view returns (uint256) {
        for (uint256 i; i < _withdrawQueue.length; ++i) {
            IERC4626 market = _withdrawQueue[i];

            _assets = UtilsLib.zeroFloorSub(_assets, market.maxWithdraw(address(this)));

            if (_assets == 0) break;
        }

        return _assets;
    }
}
