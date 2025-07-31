// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

library KinkMath {
    function isBetween(int256 _var, int256 _low, int256 _hi) internal pure returns (bool) {
        return (_low <=_var && _var <= _hi);
    }
}
