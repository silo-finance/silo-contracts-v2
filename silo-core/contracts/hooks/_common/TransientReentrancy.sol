// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

abstract contract TransientReentrancy {
    error ReentrancyGuardReentrantCall();

    bool private transient _lock;

    modifier nonReentrant() {
        require(!_lock, ReentrancyGuardReentrantCall());

        _lock = true;
        _;
        _lock = false;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "ON", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function reentrancyGuardEntered() internal view returns (bool) {
        return _lock;
    }
}
