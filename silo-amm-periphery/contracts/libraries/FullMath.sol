// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// placeholder, hopefully it can be removed for final implementation
library FullMath {
    function mulDiv(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        result = a * b;
        unchecked { result /= denominator; }
    }
}
