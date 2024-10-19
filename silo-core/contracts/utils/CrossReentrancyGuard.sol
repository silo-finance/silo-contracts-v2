// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICrossReentrancyGuard} from "../interfaces/ICrossReentrancyGuard.sol";

abstract contract CrossReentrancyGuard is ICrossReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 0;
    uint256 private constant _ENTERED = 1;

    uint256 private transient _crossReentrantStatus;

    /// @inheritdoc ICrossReentrancyGuard
    function turnOnReentrancyProtection() external virtual {
        _onlySiloOrTokenOrHookReceiver();
        
        require(_crossReentrantStatus != _ENTERED, CrossReentrantCall());

        _crossReentrantStatus = _ENTERED;
    }

    /// @inheritdoc ICrossReentrancyGuard
    function turnOffReentrancyProtection() external virtual {
        _onlySiloOrTokenOrHookReceiver();
        
        // Leaving it unprotected may lead to a bug in the reentrancy protection system,
        // as it can be used in the function without activating the protection before deactivating it.
        // Later on, these functions may be called to turn off the reentrancy protection.
        // To avoid this, we check if the protection is active before deactivating it.
        require(_crossReentrantStatus != _NOT_ENTERED, CrossReentrancyNotActive());

        _crossReentrantStatus = _NOT_ENTERED;
    }

    /// @inheritdoc ICrossReentrancyGuard
    function reentrancyGuardEntered() external view virtual returns (bool entered) {
        entered = _crossReentrantStatus == _ENTERED;
    }

    function _onlySiloOrTokenOrHookReceiver() internal virtual {}
}
