// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Math} from "openzeppelin5/utils/math/Math.sol";

import {PRBMathSD59x18} from "../lib/PRBMathSD59x18.sol";
import {IDynamicKinkModelV1} from "../interfaces/IDynamicKinkModelV1.sol";

// solhint-disable var-name-mixedcase
// solhint-disable-line function-max-lines
// solhint-disable-line code-complexity

/*
rules:
- if utilization goes up -> rcomp always go up (unless overflow, then == 0)
- if utilization goes down -> rcomp always go down?
- there should be no overflow when utilization goes down
- function should never throw (unless we will decive to remove uncheck)
*/

/// @title DynamicKinkModelV1
/// @notice Refer to Silo DynamicKinkModelV1 paper for more details.
/// @custom:security-contact security@silo.finance
contract DynamicKinkModelV1 is IDynamicKinkModelV1 {
    /// @dev DP is 18 decimal points used for integer calculations
    int256 internal constant _DP = int256(10 ** DECIMALS);

    /// @dev decimal points used by the model.
    uint256 public constant DECIMALS = 18;
    
    /// @dev universal limit for several DynamicKinkModelV1 config parameters. Follow the model whitepaper for more
    ///     information. Units of measure are vary per variable type. Any config within these limits is considered
    ///     valid.
    int256 public constant UNIVERSAL_LIMIT = 1e9 * _DP;

    /// @dev maximum value of current interest rate the model will return. This is 10,000% APR in 18-decimals.
    int256 public constant RCUR_CAP = 100 * _DP;

    /// @dev seconds per year used in interest calculations.
    int256 public constant ONE_YEAR = 365 days;

    /// @dev maximum value of compound interest per second the model will return. This is per-second rate.
    int256 public constant RCOMP_CAP = RCUR_CAP / ONE_YEAR;

    /// @dev the time limit for compounding interest. If the 100 years is exceeded, time since last transaction
    ///     is capped to this limit.
    int256 public constant HUNDRED_YEARS = 100 * ONE_YEAR;

    /// @dev maximum exp() input to prevent an overflow.
    int256 public constant X_MAX = 11 * _DP;

    /// @dev maximum value for total borrow amount, total deposits amount and compounded interest. If these
    ///     values are above the threshold, compounded interest is reduced to prevent an overflow.
    int256 public constant AMT_MAX = type(uint256).max / (2 ** 16 * _DP);

    /// @dev each Silo setup is stored separately in mapping, that's why we do not need to clone IRM
    /// at the same time this is safety feature because we will write to this mapping based on msg.sender
    /// silo => setup
    // todo InterestRateModel Config setup flow
    mapping (address => Setup) public getSetup;

    /// @inheritdoc IDynamicKinkModelV1
    function currentInterestRate(
        Setup memory _setup, 
        int256 _t0, 
        int256 _t1, 
        int256 _u,
        int256 _td,
        int256 _tba
    )
        public
        pure
        returns (int256 rcur, bool overflow, bool capped)
    {
        // _t0 < _t1 checks are included inside this function, may revert 
        (,, overflow, capped) = compoundInterestRate(
            _setup,
            _t0,
            _t1,
            _u,
            _td,
            _tba
        );

        if (overflow) {
            return (0, overflow, capped);
        }

        unchecked {
            int256 T = _t1 - _t0;

            if (T > HUNDRED_YEARS) { // TODO if we dont care about overflow, remove
                T = HUNDRED_YEARS;
            }

            // TODO we changing `k` in `compoundInterestRate`, should we use it here, or we using `_setup.k`?
            int256 k = Math.max(_setup.config.kmin, Math.min(_setup.config.kmax, _setup.k));

            if (_u < _setup.config.u1) {
                k = Math.max(
                    k - (_setup.config.c1 + _setup.config.cminus * (_setup.config.u1 - _u) / _DP) * T,
                    _setup.config.kmin
                );
            } else if (_u > _setup.config.u2) {
                k = Math.min(
                    k + Math.min(
                        _setup.config.c2 + _setup.config.cplus * (_u - _setup.config.u2) / _DP,
                        _setup.config.dmax
                    ) * T,
                    _setup.config.kmax
                );
            }


            // additional interest rate
            if (_u >= _setup.config.ulow) {
                rcur = _u - _setup.config.ulow;

                if (_u >= _setup.config.ucrit) {
                    rcur = rcur + _setup.config.alpha * (_u - _setup.config.ucrit ) / _DP;
                }

                rcur = rcur * k / _DP;
            }

            rcur = Math.min(rcur + _setup.config.rmin) * ONE_YEAR, RCUR_CAP);
        }
    }

    /// @inheritdoc IDynamicKinkModelV1
    function validateConfig(Config memory _config) public pure returns (bool) {
        return (_config.ulow >= 0 && _config.ulow < _DP) &&
            (_config.u1 >= 0 && _config.u1 < _DP) && 
            (_config.u2 >= _config.u1 && _config.u2 < _DP) &&
            (_config.ucrit >= _config.ulow && _config.ucrit < _DP) &&
            (_config.rmin >= 0 && _config.rmin < _DP) &&
            (_config.kmin >= 0 && _config.kmin < UNIVERSAL_LIMIT) &&
            (_config.kmax >= _config.kmin && _config.kmin < UNIVERSAL_LIMIT) &&
            (_config.dmax >= 0 && _config.dmax < UNIVERSAL_LIMIT) &&
            (_config.alpha >= 0 && _config.alpha < UNIVERSAL_LIMIT) &&
            (_config.cminus >= 0 && _config.cminus < UNIVERSAL_LIMIT) &&
            (_config.cplus >= 0 && _config.cplus < UNIVERSAL_LIMIT) &&
            (_config.c1 >= 0 && _config.c1 < UNIVERSAL_LIMIT) &&
            (_config.c2 >= 0 && _config.c2 < UNIVERSAL_LIMIT);
    }

    /// @inheritdoc IDynamicKinkModelV1
    function compoundInterestRate(
        Setup memory _setup, 
        int256 _t0,
        int256 _t1, 
        int256 _u,
        int256 _td,
        int256 _tba
    )
        public
        pure
        returns (int256 rcomp, int256 k, bool overflow, bool capped)
    {
        // TODO can we do early return? and what is correct `k` here? probably kmin?
        if (_tba == 0) return (0, 0, false, false);

        LocalVarsRCOMP memory _l = LocalVarsRCOMP(0, 0, 0, 0, 0, 0, 0);

        unchecked {
            if (_t1 < _t0) revert InvalidTimestamp(); // TODO remove if ok to overflow
            
            _l.T = _t1 - _t0;
            
            if (_l.T > HUNDRED_YEARS) {
                _l.T = HUNDRED_YEARS;
            }

            // roc calculations
            if (_u < _setup.config.u1) {
                _l.roc = - _setup.config.c1 - _setup.config.cminus * (_setup.config.u1 - _u) / _DP;
            } else if (_u > _setup.config.u2) {
                _l.roc = Math.min(
                    _setup.config.c2 + _setup.config.cplus * (_u - _setup.config.u2) / _DP,
                    _setup.config.dmax
                );
            }

            k = Math.max(_setup.config.kmin, Math.min(_setup.config.kmax, _setup.k));
            // slope of the kink at t1 ignoring lower and upper bounds
            _l.k1 = k + _l.roc * _l.T;

            // calculate the resulting slope state
            if (_l.k1 > _setup.config.kmax) {
                _l.x = _setup.config.kmax * _l.T - (_setup.config.kmax - k) ** 2 / (2 * _l.roc);
                k = _setup.config.kmax;
            } else if (_l.k1 < _setup.config.kmin) {
                _l.x = _setup.config.kmin * _l.T - ((_setup.k - _setup.config.kmin) ** 2) / (2 * _l.roc);
                k = _setup.config.kmin;
            } else {
                _l.x = (k + _l.k1) * _l.T / 2;
                k = _l.k1;
            }

            if (_u >= _setup.config.ulow) {
                _l.f = _u - _setup.config.ulow;

                if (_u >= _setup.config.ucrit) {
                    _l.f = _l.f + _setup.config.alpha * (_u - _setup.config.ucrit) / _DP;
                }
            }

            _l.x = _setup.config.rmin * _l.T + _l.f * _l.x / _DP;

            // Overflow Checks

            // limit x, so the exp() function will not overflow
            if (_l.x > X_MAX) {
                overflow = true;
                _l.x = X_MAX;
            }

            rcomp = PRBMathSD59x18.exp(_l.x) - _DP;

            // limit rcomp
            if (rcomp > RCOMP_CAP * _l.T) {
                capped = true;
                rcomp = RCOMP_CAP * _l.T;
            }

            _l.amt = Math.max(_tba, _td);

            // stop compounding interest for critical assets amounts
            // this IF was added in additional to the paper
            if (_l.amt > AMT_MAX) {
                overflow = true;
                rcomp = 0;
                k = _setup.config.kmin;

                return (rcomp, k, overflow, capped);
            }

            // TODO add check for overflow, we can still throw here
            _l.interest = Math.muldiv(_tba, rcomp, _DP);

            // limit accrued interest if it results in critical assets amount
            if (_l.amt > AMT_MAX - _l.interest) {
                didOverflow = true;
                // it will not underflow because above, we checking `if (_l.amt > AMT_MAX)`
                _l.interest = AMT_MAX - _l.amt;

                if (_tba == 0) {
                    rcomp = 0; // tODO if we early return, this will never happen
                } else {
                    rcomp = _l.interest * _DP / _tba;
                }
            }

            // reset the k to the min value in overflow and cap cases
            if (overflow || capped) {
                k = _setup.config.kmin;
            }
        }
    }
}

// solhint-enable var-name-mixedcase
// solhint-enable-line function-max-lines
// solhint-enable-line code-complexity
