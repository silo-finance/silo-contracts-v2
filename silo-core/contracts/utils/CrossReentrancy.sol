// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {CrossEntrancy} from "../lib/CrossEntrancy.sol";
import {Hook} from "../lib/Hook.sol";

abstract contract CrossReentrancy {
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
    uint256 internal _crossReentrantStatus;

    constructor() {
        _crossReentrantStatus = CrossEntrancy.NOT_ENTERED;
    }

    /// @dev please notice, this internal method is open TODO bug
    // solhint-disable-next-line function-max-lines, code-complexity
    function _crossNonReentrantBefore() internal virtual {
        if (_crossReentrantStatus == CrossEntrancy.ENTERED) revert ISiloConfig.CrossReentrantCall();

        _crossReentrantStatus = CrossEntrancy.ENTERED;
    }

    function _crossNonReentrantAfter() internal virtual {
        uint256 currentStatus = _crossReentrantStatus;

        // Leaving it unprotected may lead to a bug in the reentrancy protection system,
        // as it can be used in the function without activating the protection before deactivating it.
        // Later on, these functions may be called to turn off the reentrancy protection.
        // To avoid this, we check if the protection is active before deactivating it.
        if (currentStatus == CrossEntrancy.NOT_ENTERED) revert ISiloConfig.CrossReentrancyNotActive();

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _crossReentrantStatus = CrossEntrancy.NOT_ENTERED;
    }
}
