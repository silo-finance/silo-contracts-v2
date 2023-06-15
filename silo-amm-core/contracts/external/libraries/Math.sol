// SPDX-License-Identifier: GD
pragma solidity 0.8.19;

/// @dev source: uniswap-v2-core/contracts/libraries/Math.sol, adjusted to solidity 0.8.0
/// a library for performing various math operations
library Math {
    function min(uint x, uint y) internal pure returns (uint z) {
        z = x < y ? x : y;
    }

    /// @dev babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
    function sqrt(uint _y) internal pure returns (uint z) {
        unchecked {
            if (_y > 3) {
                z = _y;
                uint x = _y / 2 + 1;
                while (x < z) {
                    z = x;
                    x = (_y / x + x) / 2;
                }
            } else if (_y != 0) {
                z = 1;
            }
        }
    }
}
