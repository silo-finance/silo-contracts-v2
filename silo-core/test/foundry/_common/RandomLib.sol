// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Strings} from "openzeppelin5/utils/Strings.sol";

library RandomLib {
    /// @dev _min < _n < _max
    function randomInside(uint256 _n, uint256 _min, uint256 _max) internal pure returns (uint256) {
        require(
            _min + 1 < _max,
            string.concat("invalid range for randomInside:", Strings.toString(_min), " + 1 < ", Strings.toString(_max))
        );

        if (_min < _n && _n < _max) return _n;

        uint256 diff = _max - _min - 1;
        return _min + 1 + (_n % diff);
    }

    /// @dev _min <= _n <= _max
    function randomBetween(uint256 _n, uint256 _min, uint256 _max) internal pure returns (uint256) {
        require(
            _min <= _max, 
            string.concat("invalid range for randomBetween:", Strings.toString(_min), " <= ", Strings.toString(_max))
        );

        uint256 diff = _max - _min;
        
        if (diff == 0) return _min;
        if (diff == type(uint256).max) return _n;
        if (_min <= _n && _n <= _max) return _n;
        if (diff == _max) return _n % (_max + 1);

        return _min + (_n % (diff + 1));
    }

    /// @dev _min < _n <= _max
    function randomAbove(uint256 _n, uint256 _min, uint256 _max) internal pure returns (uint256) {
        require(
            _min < _max, 
            string.concat("invalid range for randomAbove:", Strings.toString(_min), " < ", Strings.toString(_max))
        );

        uint256 diff = _max - _min;
        if (diff == 0) return _min;
        if (_min < _n && _n <= _max) return _n;

        return _min + 1 + (_n % diff);
    }

    /// @dev _min <= _n < _max
    function randomBelow(uint256 _n, uint256 _min, uint256 _max) internal pure returns (uint256) {
        require(
            _min < _max, 
            string.concat("invalid range for randomBelow:", Strings.toString(_min), " < ", Strings.toString(_max))
        );

        uint256 diff = _max - _min;
        if (diff == 0) return _min;
        if (_min <= _n && _n < _max) return _n;

        return _min + (_n % diff);
    }
}