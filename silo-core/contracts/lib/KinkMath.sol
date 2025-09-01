// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

library KinkMath {
    function isBetween(int256 _var, int256 _lowIncluded, int256 _hiIncluded) internal pure returns (bool) {
        return (_lowIncluded <=_var && _var <= _hiIncluded);
    }

    function isInBelow(int256 _var, int256 _lowIncluded, int256 _hiExcluded) internal pure returns (bool) {
        return (_lowIncluded <=_var && _var < _hiExcluded);
    }

    function isInAbove(int256 _var, int256 _lowExcluded, int256 _hiIncluded) internal pure returns (bool) {
        return (_lowExcluded < _var && _var <= _hiIncluded);
    }

    function isInside(int256 _var, int256 _lowExcluded, int256 _hiExcluded) internal pure returns (bool) {
        return (_lowExcluded < _var && _var < _hiExcluded);
    }

    function willOverflowOnCastToInt256(uint256 _value) internal pure returns (bool) {
        return _value > uint256(type(int256).max);
    }
}
