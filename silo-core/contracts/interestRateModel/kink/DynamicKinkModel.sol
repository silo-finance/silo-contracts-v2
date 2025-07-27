// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SafeCast} from "openzeppelin5/utils/math/SafeCast.sol";
import {PRBMathSD59x18} from "../../lib/PRBMathSD59x18.sol";
import {IInterestRateModel} from "../../interfaces/IInterestRateModel.sol";
import {IDynamicKinkModel} from "../../interfaces/IDynamicKinkModel.sol";
import {IDynamicKinkModelConfig} from "../../interfaces/IDynamicKinkModelConfig.sol";

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

/// @title DynamicKinkModel
/// @notice Refer to Silo DynamicKinkModel paper for more details.
/// @custom:security-contact security@silo.finance
contract DynamicKinkModel is IDynamicKinkModel {
    /// @dev DP in 18 decimal points used for integer calculations
    int256 internal constant _DP = int256(1e18);

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
    int256 public constant AMT_MAX = 1766847064778384329583297500742918515827483896875618958; // type(uint256).max / uint256(2 ** 16 * _DP);

    /// @dev each Silo setup is stored separately in mapping, that's why we do not need to clone IRM
    /// at the same time this is safety feature because we will write to this mapping based on msg.sender
    /// silo => setup
    // todo InterestRateModel Config setup flow
    mapping(address silo => Setup irmStorage) public getSetup;

    /// @dev Config for the model
    IDynamicKinkModelConfig public irmConfig;

    // TODO inherit IInterestRateModel /// @inheritdoc IInterestRateModel
    function initialize(address _irmConfig) external virtual {
        require(_irmConfig != address(0), AddressZero());
        require(address(irmConfig) == address(0), AlreadyInitialized());

        irmConfig = IDynamicKinkModelConfig(_irmConfig);

        emit Initialized(_irmConfig);
    }

    /// @inheritdoc IDynamicKinkModel
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
        (,, overflow, capped) = compoundInterestRate({
            _setup: _setup,
            _t0: _t0,
            _t1: _t1,
            _u: _u,
            _td: _td,
            _tba: _tba
        });

        if (overflow) {
            return (0, overflow, capped);
        }

        unchecked {
            int256 T = _t1 - _t0;

            if (T > HUNDRED_YEARS) {
                // TODO if we dont care about overflow, remove
                T = HUNDRED_YEARS;
            }

            // TODO we changing `k` in `compoundInterestRate`, should we use it here, or we using `_setup.k`?
            int256 k = _max(_setup.config.kmin, _min(_setup.config.kmax, _setup.k));

            if (_u < _setup.config.u1) {
                k = _max(
                    k - (_setup.config.c1 + _setup.config.cminus * (_setup.config.u1 - _u) / _DP) * T,
                    _setup.config.kmin
                );
            } else if (_u > _setup.config.u2) {
                k = _min(
                    k + _min(
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

            rcur = _min((rcur + _setup.config.rmin) * ONE_YEAR, RCUR_CAP);
        }
    }

    /// @inheritdoc IDynamicKinkModel
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
                _l.roc = -_setup.config.c1 - _setup.config.cminus * (_setup.config.u1 - _u) / _DP;
            } else if (_u > _setup.config.u2) {
                _l.roc = _min(
                    _setup.config.c2 + _setup.config.cplus * (_u - _setup.config.u2) / _DP,
                    _setup.config.dmax
                );
            }

            k = _max(_setup.config.kmin, _min(_setup.config.kmax, _setup.k));
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

            _l.amt = _max(_tba, _td);

            // stop compounding interest for critical assets amounts
            // this IF was added in additional to the paper
            if (_l.amt > AMT_MAX) {
                overflow = true;
                rcomp = 0;
                k = _setup.config.kmin;

                return (rcomp, k, overflow, capped);
            }

            // TODO add check for overflow, we can still throw here
            // TODO should we use mulDiv?
            _l.interest = _tba * rcomp / _DP;

            // limit accrued interest if it results in critical assets amount
            if (_l.amt > AMT_MAX - _l.interest) {
                overflow = true;
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

    function _min(int256 _a, int256 _b) internal pure returns (int256) {
        return _a < _b ? _a : _b;
    }

    function _max(int256 _a, int256 _b) internal pure returns (int256) {
        return _a > _b ? _a : _b;
    }
}
// solhint-enable var-name-mixedcase
// solhint-enable-line function-max-lines
// solhint-enable-line code-complexity
