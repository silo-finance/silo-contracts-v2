import {Strings} from "openzeppelin5/utils/Strings.sol";

library RandomLib {
    function randomInside(uint256 _n, uint256 _min, uint256 _max) internal pure returns (uint256) {
        require(
            _min + 1 < _max, 
            string.concat("invalid range for randomInside:", Strings.toString(_min), " + 1 < ", Strings.toString(_max))
        );

        uint256 diff = _max - _min - 1;
        return _min + 1 + (_n % diff);
    }

    function randomBetween(uint256 _n, uint256 _min, uint256 _max) internal pure returns (uint256) {
        require(
            _min <= _max, 
            string.concat("invalid range for randomBetween:", Strings.toString(_min), " <= ", Strings.toString(_max))
        );

        uint256 diff = _max - _min;
        if (diff == 0) return _min;

        return _min + (_n % (diff + 1));
    }

    function randomAbove(uint256 _n, uint256 _min, uint256 _max) internal pure returns (uint256) {
        require(
            _min < _max, 
            string.concat("invalid range for randomAbove:", Strings.toString(_min), " < ", Strings.toString(_max))
        );

        uint256 diff = _max - _min;
        if (diff == 0) return _min;

        return _min + 1 + (_n % diff);
    }

    function randomBelow(uint256 _n, uint256 _min, uint256 _max) internal pure returns (uint256) {
        require(
            _min < _max, 
            string.concat("invalid range for randomBelow:", Strings.toString(_min), " < ", Strings.toString(_max))
        );

        uint256 diff = _max - _min;
        if (diff == 0) return _min;

        return _min + (_n % diff);
    }
}