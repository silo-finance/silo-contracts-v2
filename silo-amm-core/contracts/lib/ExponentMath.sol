// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/// @dev all operations on exponent can be unchecked because - see documentation for `m` and `e`
struct Exponent {
    /// @dev we need to keep it between 0.5 and 1.0 (1e18) so 64bits are enough,
    /// our precision is 1e18 (64b), we doing mul on that, but outside of Exponent, inside max we need it 64b
    uint64 m;
    /// @dev for `e` 64b should be more than enough, we doing only + or - on `e` so it is relatively small
    uint64 e;
}

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

    function toExp(uint256 _scalar) internal pure returns (Exponent memory exp) {
        unchecked {
            // we will not overflow on +1 because `base2` can return at most e=196
            exp.e = base2(_scalar) + 1;
            // we will not overflow on `* _PRECISION` because of check `_scalar > _MAX_SCALAR`
            // we will not overflow on `** exp.e` because `e` is based on `_scalar`
            exp.m = uint64(_scalar * _PRECISION / (uint256(2) ** exp.e));
        }
    }

    function fromExp(Exponent memory _exp) internal pure returns (uint256 scalar) {
        if (_exp.e > _MAX_E) revert EXP_TO_SCALAR_OVERFLOW();

        // we can not overflow because we check for `_exp.e > _MAX_E`
        unchecked { scalar = uint256(_exp.m) * uint256(2) ** _exp.e / _PRECISION; }
    }

    function mul(Exponent memory _exp, uint256 _scalar) internal pure returns (Exponent memory exp) {
        exp = toExp(_scalar);

        unchecked {
            return normaliseUp(uint128(_exp.m) * uint128(exp.m) / _PRECISION, _exp.e + exp.e);
        }
    }

    function add(Exponent memory _exp1, Exponent memory _exp2) internal pure returns (Exponent memory) {
        unchecked {
            if (_exp1.e > _exp2.e) {
                uint256 eDiff = _exp1.e - _exp2.e;
                _exp2.e += uint64(eDiff); // safe cast, because this is already in other e
                _exp2.m >>= eDiff;
            } else if (_exp2.e > _exp1.e) {
                uint256 eDiff = _exp2.e - _exp1.e;
                _exp1.e += uint64(eDiff); // safe cast, because this is already in other e
                _exp1.m >>= eDiff;
            }

            return normaliseDown(_exp1.m + _exp2.m, _exp1.e);
        }
    }

    function sub(Exponent memory _exp1, Exponent memory _exp2) internal pure returns (Exponent memory) {
        unchecked {
            if (_exp1.e > _exp2.e) {
                uint256 eDiff = _exp1.e - _exp2.e;
                _exp1.e -= uint64(eDiff); // safe cast, because this is already in other e
                _exp1.m <<= eDiff;
            } else if (_exp2.e > _exp1.e) {
                uint256 eDiff = _exp2.e - _exp1.e;
                _exp2.e -= uint64(eDiff); // safe cast, because this is already in other e
                _exp2.m <<= eDiff;
            }

            if (_exp1.m < _exp2.m) revert SUB_UNDERFLOW();
            return normaliseUp(_exp1.m - _exp2.m, _exp1.e);
        }
    }

    /// @dev this method is for keeping mantisa in expected range 0.5 <= m <= 1.0
    function normaliseDown(uint128 _m, uint128 _e) internal pure returns (Exponent memory exp) {
        while (_m > _PRECISION) {
            unchecked {
                // arbitrary magic number discovered based on avg gas consumption for tests
                _m >>= 1;
                _e += 1;
            }
        }

        if (_e > type(uint64).max) revert E_OVERFLOW();

        // after normalisation m should fit into 64b based on loops conditions
        return Exponent(uint64(_m), uint64(_e));
    }

    /// @dev this method is for keeping mantisa in expected range 0.5 <= m <= 1.0
    function normaliseUp(uint128 _m, uint128 _e) internal pure returns (Exponent memory) {
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
        return Exponent(uint64(_m), uint64(_e));
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
