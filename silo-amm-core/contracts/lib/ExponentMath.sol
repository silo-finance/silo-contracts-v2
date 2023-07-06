// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;


/// @notice DO NOT USE THIS LIB FOR EXPONENT THAT WAS NOT CREATED BY IT - THERE IS A RISK OF OVER/UNDER-FLOW
library ExponentMath {
    /// @dev biggest number that can be translated to exponent type and back
    uint256 internal constant _MAX_SCALAR = 2 ** 196 - 1;

    /// @dev biggest `e` that allows to translate exponent back to scalar
    uint256 internal constant _MAX_E = 196;
    uint128 internal constant _PRECISION = 1e18;

    /// @dev mantisa precision for 1.0

    /// @dev minimal mantisa is 0.5
    uint64 internal constant _MINIMAL_MANTISA = 1e18 / 2;

    error ZERO();
    error MAX_SCALAR();
    error SCALAR_OVERFLOW();
    error E_OVERFLOW();
    error E_UNDERFLOW();
    error EXP_TO_SCALAR_OVERFLOW();
    error SUB_UNDERFLOW();

    function toExp(uint256 _scalar) internal pure returns (uint64 m, uint64 e) {
        unchecked {
            // we will not overflow on +1 because `base2` can return at most e=196
            e = base2(_scalar) + 1;
            // we will not overflow on `* _PRECISION` because of check `_scalar > _MAX_SCALAR`
            // we will not overflow on `** exp.e` because `e` is based on `_scalar`
            m = uint64(_scalar * _PRECISION / (uint256(2) ** e));
        }
    }

    function fromExp(uint64 _m, uint64 _e) internal pure returns (uint256 scalar) {
        if (_e > _MAX_E) revert EXP_TO_SCALAR_OVERFLOW();

        // we can not overflow because we check for `e > _MAX_E`
        unchecked { scalar = uint256(_m) * uint256(2) ** _e / _PRECISION; }
    }

    function mul(uint64 _m, uint64 _e, uint256 _scalar) internal pure returns (uint64 m, uint64 e) {
        (m, e) = toExp(_scalar);

        unchecked {
            return normaliseUp(uint128(m) * uint128(_m) / _PRECISION, e + _e);
        }
    }

    function add(uint64 _m1, uint64 _e1, uint64 _m2, uint64 _e2) internal pure returns (uint64 m, uint64 e) {
        unchecked {
            if (_e1 > _e2) {
                uint256 eDiff = _e1 - _e2;
                _e2 += uint64(eDiff); // safe cast, because this is already in other e
                _m2 >>= eDiff;
            } else if (_e2 > _e1) {
                uint256 eDiff = _e2 - _e1;
                _e1 += uint64(eDiff); // safe cast, because this is already in other e
                _m1 >>= eDiff;
            }

            return normaliseDown(_m1 + _m2, _e1);
        }
    }

    function sub(uint64 _m1, uint64 _e1, uint64 _m2, uint64 _e2) internal pure returns (uint64 m, uint64 e) {
        unchecked {
            if (_e1 > _e2) {
                uint256 eDiff = _e1 - _e2;
                _e1 -= uint64(eDiff); // safe cast, because this is already in other e
                _m1 <<= eDiff;
            } else if (_e2 > _e1) {
                uint256 eDiff = _e2 - _e1;
                _e2 -= uint64(eDiff); // safe cast, because this is already in other e
                _m2 <<= eDiff;
            }

            if (_m1 < _m2) revert SUB_UNDERFLOW();

            return normaliseUp(_m1 - _m2, _e1);
        }
    }

    /// @dev this method is for keeping mantisa in expected range 0.5 <= m <= 1.0
    function normaliseDown(uint128 _m, uint128 _e) internal pure returns (uint64 m, uint64 e) {
        while (_m > _PRECISION) {
            unchecked {
                // arbitrary magic number discovered based on avg gas consumption for tests
                _m >>= 1;
                _e += 1;
            }
        }

        if (_e > type(uint64).max) revert E_OVERFLOW();

        // after normalisation m should fit into 64b based on loops conditions
        return (uint64(_m), uint64(_e));
    }

    /// @dev this method is for keeping mantisa in expected range 0.5 <= m <= 1.0
    function normaliseUp(uint128 _m, uint128 _e) internal pure returns (uint64 m, uint64 e) {
        uint256 initialE = _e;

        while (_m < _MINIMAL_MANTISA) {
            unchecked {
                _m <<= 1;
                _e -= 1;
            }
        }

        // in general, for exp managed by this lib we should not have situation when e underflow
        // but it cost only ~80gas to be 100% sure
        if (_e > initialE) revert E_UNDERFLOW();

        // after normalisation m should fit into 64b based on loops conditions
        return (uint64(_m), uint64(_e));
    }

    /// @dev optimised method to find exponent for scalar
    /// @return e maximal exponent that meet the condition: 2^e < `_scalar`
    function base2(uint256 _scalar) internal pure returns (uint64 e) {
        if (_scalar == 0) revert ZERO();
        if (_scalar > _MAX_SCALAR) revert SCALAR_OVERFLOW();

        uint256 s = 2;

        while (s <= _scalar) {
            unchecked {
                // arbitrary magic number discovered based on avg gas consumption for tests
                e += 16; // `e` will not get higher than 196, because max `_scalar` is up to 196b, even if `196 + 16` ok
                s <<= 16; // this will be max 2 ** (196 + 16), so no overflow
            }
        }

        // if we ever go "up"
        if (s != 2) {
            while (s > _scalar) {
                unchecked {
                    // magic number that must be divider of arbitrary number from previous while loop
                    // discovered based on avg gas consumption for tests
                    e -= 4; // if we ever did +16, going back -4 and reverse condition will do no underflow
                    s >>= 4; // ^ same here
                }
            }
        }

        while (s <= _scalar) {
            unchecked {
                // magic number that must be 1, because in last step we need to be precise, so step is 1
                e += 1; // we safe for same reasons as for 1st loop
                s <<= 1;
            }
        }
    }
}
