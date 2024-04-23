// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

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

    function _crossNonReentrantBefore(uint256 _hookAction) internal virtual {
        uint256 crossReentrantStatusCached = _crossReentrantStatus;

        // On the first call to nonReentrant, _status will be CrossEntrancy.NOT_ENTERED
        if (crossReentrantStatusCached == CrossEntrancy.NOT_ENTERED) {
            // Any calls to nonReentrant after this point will fail
            _crossReentrantStatus = CrossEntrancy.ENTERED;
            return;
        }

        if (crossReentrantStatusCached == CrossEntrancy.ENTERED_FROM_LEVERAGE && _hookAction == Hook.DEPOSIT) {
            // on leverage, entrance from deposit is allowed, but allowance is removed when we back to Silo
            _crossReentrantStatus = CrossEntrancy.ENTERED;
            return;
        }

        revert ISiloConfig.CrossReentrantCall();
    }

    function _crossLeverageGuard(uint256 _entranceFrom) internal virtual {
        if (_crossReentrantStatus == CrossEntrancy.ENTERED && _entranceFrom == CrossEntrancy.ENTERED_FROM_LEVERAGE) {
            // we need to be inside leverage and before callback, we mark our status
            _crossReentrantStatus = CrossEntrancy.ENTERED_FROM_LEVERAGE;
            return;
        }

        revert ISiloConfig.CrossReentrantCall();
    }

    function _crossNonReentrantAfter() internal virtual {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _crossReentrantStatus = CrossEntrancy.NOT_ENTERED;
    }
}
