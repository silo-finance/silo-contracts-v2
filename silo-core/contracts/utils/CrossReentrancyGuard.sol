// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICrossReentrancyGuard} from "../interfaces/ICrossReentrancyGuard.sol";

abstract contract CrossReentrancyGuard is ICrossReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint24 private constant _NOT_ENTERED = 1;
    uint24 private constant _ENTERED = 2;

    uint256 private _crossReentrantStatus;

    constructor() {
        _crossReentrantStatus = _NOT_ENTERED;
    }

    /// @inheritdoc ICrossReentrancyGuard
    function turnOnReentrancyProtection() external virtual {
        _onlySiloOrTokenOrHookReceiver();
        
        if (_crossReentrantStatus == _ENTERED) revert CrossReentrantCall();

        _crossReentrantStatus = _ENTERED;
    }

    /// @inheritdoc ICrossReentrancyGuard
    function turnOffReentrancyProtection() external virtual {
        _onlySiloOrTokenOrHookReceiver();
        
        // Leaving it unprotected may lead to a bug in the reentrancy protection system,
        // as it can be used in the function without activating the protection before deactivating it.
        // Later on, these functions may be called to turn off the reentrancy protection.
        // To avoid this, we check if the protection is active before deactivating it.
        if (_crossReentrantStatus == _NOT_ENTERED) revert CrossReentrancyNotActive();

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _crossReentrantStatus = _NOT_ENTERED;
    }

    /// @inheritdoc ICrossReentrancyGuard
    function reentrancyGuardEntered() external view virtual returns (bool entered) {
        entered = _crossReentrantStatus == _ENTERED;
    }

    function _onlySiloOrTokenOrHookReceiver() internal virtual {}
}
