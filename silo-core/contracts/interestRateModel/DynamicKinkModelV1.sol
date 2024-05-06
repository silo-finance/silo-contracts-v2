// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {SafeCast} from "openzeppelin-contracts/utils/math/SafeCast.sol";
import {Math} from "openzeppelin-contracts/utils/math/Math.sol";

import {PRBMathSD59x18} from "../lib/PRBMathSD59x18.sol";
import {IInterestRateModel} from "../interfaces/IInterestRateModel.sol";
import {IDynamicKinkModelV1} from "../interfaces/IDynamicKinkModelV1.sol";

// solhint-disable var-name-mixedcase

/// @title DynamicKinkModelV1
/// @custom:security-contact security@silo.finance
contract DynamicKinkModelV1 is IDynamicKinkModelV1 {
    using PRBMathSD59x18 for int256;

    error InvalidTimestamp();
    error HundredYearsExceeded();

    // returns decimal points used by model
    uint256 public constant DECIMALS = 18;
    /// @dev DP is 18 decimal points used for integer calculations
    int256 internal constant _DP = int256(10 ** DECIMALS);

    int256 public constant SECONDS_IN_YEAR = 365 * 24 * 60 * 60;
    int256 public constant HUNDRED_YEARS = 100 * SECONDS_IN_YEAR;

    // limit for some variables, including kmin and kmax
    int256 public constant CONFIG_CONSTANTS_FIRST_LIMIT = 10**16 * _DP;
    // limit for some variables, including dmax
    int256 public constant CONFIG_CONSTANTS_SECOND_LIMIT = 10**22 * _DP;


    int256 public constant X_MAX = 11 * _DP;

    /// @dev maximum value of current interest rate the model will return. This is 10,000% APR in the 18-decimals format
    int256 public constant R_CURRENT_MAX = 100 * _DP;
    int256 public constant AMT_MAX = (type(int256).max - 1) / (2 ** 16 * _DP);

    /// @dev maximum value of compound interest per second the model will return. This is per-second rate.
    int256 public constant R_COMPOUND_MAX_PER_SECOND = R_CURRENT_MAX / (365 * 24 * 3600);

    /// @dev each Silo setup is stored separately in mapping, that's why we do not need to clone IRM
    /// at the same time this is safety feature because we will write to this mapping based on msg.sender
    /// silo => setup
    mapping (address => Setup) public getSetup;

    /// @dev optional method that can connect silo to it's model state on silo initialization
    /// can be empty by must implement interface.
    function connect(address _configAddress) external {

    }

    /// @dev get compound interest rate and update model storage for current block.timestamp
    /// @param _collateralAssets total silo collateral assets
    /// @param _debtAssets total silo debt assets
    /// @param _interestRateTimestamp last IRM timestamp
    /// @return rcomp compounded interest rate from last update until now (1e18 == 100%)
    function getCompoundInterestRateAndUpdate(
        uint256 _collateralAssets,
        uint256 _debtAssets,
        uint256 _interestRateTimestamp
    ) external returns (uint256 rcomp) {}

    function currentInterestRate(
        Setup memory _setup, 
        int256 _t0, 
        int256 _t1, 
        int256 _u,
        int256 _totalDeposits,
        int256 _totalBorrowAmount
    )
        public
        pure
        returns (int256 rcur, bool didCap, bool didOverflow)
    {
        // _t0 < _t1 checks are included inside this function, may revert 
        (,, didCap, didOverflow) = compoundInterestRate(
            _setup,
            _t0,
            _t1,
            _u,
            _totalDeposits,
            _totalBorrowAmount
        );

        if (didOverflow) {
            return (0, didCap, didOverflow);
        }

        //todo link to paper proving that the overflow is impossible in this block
        unchecked {
            int256 T = _t1 - _t0;
            int256 k;

            if (_u < _setup.config.u1) {
                k = _setup.k - (_setup.config.c1 + _setup.config.cminus * (_setup.config.u1 - _u) / _DP) * T;
                k = k > _setup.config.kmin ? k : _setup.config.kmin;
            } else if (_u > _setup.config.u2) {
                int256 dkdt = (_setup.config.c2 + _setup.config.cplus * (_u - _setup.config.u2) / _DP);
                dkdt = dkdt > _setup.config.dmax ? _setup.config.dmax : dkdt;
                k = _setup.k + dkdt * T;
                k = k > _setup.config.kmax ? _setup.config.kmax : k;
            } else {
                k = _setup.k;
            }

            if (_u >= _setup.config.ulow) {
                rcur = _u - _setup.config.ulow;

                if (_u >= _setup.config.ucrit) {
                    rcur = rcur + _setup.config.alpha * (_u - _setup.config.ucrit ) / _DP;
                }

                rcur = rcur * k / _DP;
            }

            rcur = (rcur + _setup.config.rmin) * SECONDS_IN_YEAR;
        }
    }

    /// @dev get compound interest rate
    /// @param _t0 timestamp of last calculation
    /// @param _t1 current timestamp
    /// @param _u utilization at time t0
    /// @return rcomp compounded interest rate
    /// @return k updated state of the slope k at time t1

    struct LocalVarsRCOMP {
        int256 T;
        int256 k1;
        int256 f;
        int256 roc;
        int256 x;
        int256 assetsAmount;
        int256 interest;
    }

    // true if valid, false invalid
    // todo link to paper
    function validateConfig(Config memory _config) public pure returns (bool) {
        return (_config.ulow >= 0 && _config.ulow < _DP) &&
            (_config.u1 >= 0 && _config.u1 < _DP) && 
            (_config.u2 >= _config.u1 && _config.u2 < _DP) &&
            (_config.ucrit >= _config.ulow && _config.ucrit < _DP) &&
            (_config.rmin >= 0 && _config.rmin < _DP) &&
            (_config.kmin >= 0 && _config.kmin < CONFIG_CONSTANTS_FIRST_LIMIT) &&
            (_config.kmax >= _config.kmin && _config.kmin < CONFIG_CONSTANTS_FIRST_LIMIT) &&
            (_config.dmax >= 0 && _config.dmax < CONFIG_CONSTANTS_SECOND_LIMIT) &&
            (_config.alpha >= 0 && _config.alpha < CONFIG_CONSTANTS_FIRST_LIMIT) &&
            (_config.cminus >= 0 && _config.cminus < CONFIG_CONSTANTS_SECOND_LIMIT) &&
            (_config.cplus >= 0 && _config.cplus < CONFIG_CONSTANTS_SECOND_LIMIT) &&
            (_config.c1 >= 0 && _config.c1 < CONFIG_CONSTANTS_SECOND_LIMIT) &&
            (_config.c2 >= 0 && _config.c2 < CONFIG_CONSTANTS_SECOND_LIMIT);
    }
    function compoundInterestRate(
        Setup memory _setup, 
        int256 _t0,
        int256 _t1, 
        int256 _u,
        int256 _totalDeposits,
        int256 _totalBorrowAmount
    )
        public
        pure
        returns (int256 rcomp, int256 k, bool didCap, bool didOverflow)
    {
        LocalVarsRCOMP memory _l = LocalVarsRCOMP(0, 0, 0, 0, 0, 0, 0);

        //todo link to paper proving that the overflow is impossible in this block
        unchecked {
            if (_t1 < _t0) revert InvalidTimestamp();
            
            _l.T = _t1 - _t0;
            
            if (_l.T > HUNDRED_YEARS) revert HundredYearsExceeded();

            // roc calculations
            if (_u < _setup.config.u1) {
                _l.roc = - _setup.config.c1 - _setup.config.cminus * (_setup.config.u1 - _u) / _DP;
            } else if (_u > _setup.config.u2) {
                _l.roc = _setup.config.c2 + _setup.config.cplus * (_u - _setup.config.u2) / _DP;
                _l.roc = _l.roc > _setup.config.dmax ? _setup.config.dmax : _l.roc;
            }
            
            // k1 based on roc
            _l.k1 = _setup.k + _l.roc * _l.T;

            // calculate the resulting slope state
            if (_l.k1 > _setup.config.kmax) {
                _l.x = _setup.config.kmax * _l.T - (_setup.config.kmax - _setup.k) ** 2 / (2 * _l.roc);
                k = _setup.config.kmax;
            } else if (_l.k1 < _setup.config.kmin) {
                _l.x = _setup.config.kmin * _l.T - ((_setup.k - _setup.config.kmin) ** 2) / (2 * _l.roc);
                k = _setup.config.kmin;
            } else {
                _l.x = (_setup.k + _l.k1) * _l.T / 2;
                k = _l.k1;
            }

            if (_u >= _setup.config.ulow) {
                _l.f = _u - _setup.config.ulow;

                if (_u >= _setup.config.ucrit) {
                    _l.f = _l.f + _setup.config.alpha * (_u - _setup.config.ucrit) / _DP;
                }
            }

            // apply the limit for x, because the f*x operation can overflow
            if (_l.x > X_MAX) {
                didOverflow = true;
                _l.x = X_MAX;
            }

            _l.x = _setup.config.rmin * _l.T + _l.f * _l.x / _DP;

            // limit x, so the exp() function will not overflow
            if (_l.x > X_MAX) {
                didOverflow = true;
                _l.x = X_MAX;
            }

            rcomp = _l.x.exp() - _DP;

            // limit rcomp
            if (rcomp > R_COMPOUND_MAX_PER_SECOND * _l.T) {
                didCap = true;
                rcomp = R_COMPOUND_MAX_PER_SECOND * _l.T;
            }

            _l.assetsAmount = _totalDeposits > _totalBorrowAmount ? _totalDeposits : _totalBorrowAmount;

            // stop compounding interest for critical assets amounts
            if (_l.assetsAmount > AMT_MAX) {
                didOverflow = true;
                rcomp = 0;
                k = _setup.config.kmin;

                return (rcomp, k, didCap, didOverflow);
            }

            _l.interest = _totalBorrowAmount * rcomp / _DP;

            // limit accrued interest if it results in critical assets amount
            if (_l.assetsAmount + _l.interest > AMT_MAX) {
                didOverflow = true;
                _l.interest = AMT_MAX - _l.assetsAmount;

                if (_totalBorrowAmount == 0) {
                    rcomp = 0;
                } else {
                    rcomp = _l.interest * _DP / _totalBorrowAmount;
                }
            }

            // reset the k to the min value in overflow and cap cases
            if (didOverflow || didCap) {
                k = _setup.config.kmin;
            }
        }
    }
}

// solhint-enable var-name-mixedcase
