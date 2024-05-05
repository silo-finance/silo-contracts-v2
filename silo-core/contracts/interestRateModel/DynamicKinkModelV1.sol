// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {SafeCast} from "openzeppelin-contracts/utils/math/SafeCast.sol";
import {Math} from "openzeppelin-contracts/utils/math/Math.sol";

import {PRBMathSD59x18} from "../lib/PRBMathSD59x18.sol";
import {IInterestRateModel} from "../interfaces/IInterestRateModel.sol";
import {IDynamicKinkModelV1} from "../interfaces/IDynamicKinkModelV1.sol";

// solhint-disable var-name-mixedcase
// solhint-disable func-name-mixedcase

/// @title DynamicKinkModelV1
/// @custom:security-contact security@silo.finance
contract DynamicKinkModelV1 is IDynamicKinkModelV1 {
    using PRBMathSD59x18 for int256;
    using SafeCast for int256;
    using SafeCast for uint256;
    // todo safecast

    error InvalidTimestamp();
    error HundredYearsExceeded();

    // todo
    // returns decimal points used by model
    uint256 public constant DECIMALS = 18;
    /// @dev DP is 18 decimal points used for integer calculations
    int256 internal constant _DP = int256(10 ** DECIMALS);

    int256 public constant HUNDRED_YEARS = 100 * 365 * 24 * 60 * 60;

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

    function currentInterestRate(Setup memory _setup, int256 _t0, int256 _t1, int256 _u)
        public
        pure
        returns (int256 rcur, int256 k, int256 r)
    {
        // uint T = t1 - t0; // length of time period (in seconds )
        if (_t1 <= _t0) revert InvalidTimestamp();
        int256 T = _t1 - _t0;

        // todo 
        k = _setup.k;

        // if (u < u1) {
        if (_u < _setup.config.u1) {
            // k = max (_k - (c1 + cminus * (u1 - u) / _DP) * T, kmin );
            k = k - (_setup.config.c1 + _setup.config.cminus * (_setup.config.u1 - _u) / _DP) * T;
            k = k > _setup.config.kmin ? k : _setup.config.kmin;
        //else if (u > u2) {
        } else if (_u > _setup.config.u2) {
            // k = min (_k + min(c2 + cplus * (u - u2) / _DP , dmax ) * T, kmax );
            int256 dkdt = (_setup.config.c2 + _setup.config.cplus * (_u - _setup.config.u2) / _DP);
            dkdt = dkdt > _setup.config.dmax ? _setup.config.dmax : dkdt;
            k = (k + dkdt) * T;
            k = k > _setup.config.kmax ? _setup.config.kmax : k;
        } else {
            // todo
            k = k;
        }

        // if (u >= ulow ) {
        if (_u >= _setup.config.ulow) {
            //r = u - ulow ;
            r = _u - _setup.config.ulow;

            // if (u >= ucrit ) {
            if (_u >= _setup.config.ucrit) {
                //r = r + alpha * (u - ucrit ) / _DP;
                r = r + _setup.config.alpha * (_u - _setup.config.ucrit ) / _DP;
            }

            // r = r * k / _DP;
            r = r * k / _DP;
        }

        // rcur = (r + rmin ) * 365 * 24 * 3600;
        // todo move multiplier
        rcur = (r + _setup.config.rmin) * 365 * 24 * 3600;
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
    function compoundInterestRate(Setup memory _setup, int256 _t0, int256 _t1, int256 _u, int256 _totalDeposits, int256 _totalBorrowAmount)
        public
        pure
        returns (int256 rcomp, int256 k, bool didOverflow , bool didCap)
    {
        LocalVarsRCOMP memory _l = LocalVarsRCOMP(0, 0, 0, 0, 0, 0, 0);
        // uint T = t1 - t0;
        if (_t1 <= _t0) revert InvalidTimestamp();
        _l.T = _t1 - _t0;
        
        if (_l.T > HUNDRED_YEARS) {
            revert HundredYearsExceeded();
        }

        // if (u < u1) {
        if (_u < _setup.config.u1) {
            // roc = - c1 - cminus * (u1 - u) / _DP;
            _l.roc = - _setup.config.c1 - _setup.config.cminus * (_setup.config.u1 - _u) / _DP;
        // } else if (u > u2) {       
        } else if (_u > _setup.config.u2) {
            // roc = min (c2 + cplus * (u - u2) / _DP , dmax );
            _l.roc = _setup.config.c2 + _setup.config.cplus * (_u - _setup.config.u2) / _DP;
            _l.roc = _l.roc > _setup.config.dmax ? _setup.config.dmax : _l.roc;
        } else {
            // todo remove pointless
            _l.roc = 0;
        }
        
        _l.k1 = _setup.k + _l.roc * _l.T; // slope of the kink at t1 ignoring lower and upper bounds

        // int256 x; // an integral of k

        // if (k1 > kmax ) {
        if (_l.k1 > _setup.config.kmax) {
            // x = kmax * T - ( kmax - _k)**2 / (2 * roc );
            _l.x = _setup.config.kmax * _l.T - (_setup.config.kmax - _setup.k) ** 2 / (2 * _l.roc);
            // k = kmax ;
            k = _setup.config.kmax;
        // } else if (k1 < kmin ) {
        } else if (_l.k1 < _setup.config.kmin) {
            // x = kmin * T - (_k - kmin ) **2 / (2 * roc );
            _l.x = _setup.config.kmin * _l.T - ((_setup.k - _setup.config.kmin)**2) / (2 * _l.roc);
            // k = kmin ;
            k = _setup.config.kmin;
        } else {
            // x = (_k + k1) * T / 2;
            _l.x = (_setup.k + _l.k1) * _l.T / 2;
            // k = k1;
            k = _l.k1;
        }

        // if (u >= ulow ) {
        if (_u >= _setup.config.ulow) {
            // f = u - ulow ;
            _l.f = _u - _setup.config.ulow;
            // if (u >= ucrit ) {
            if (_u >= _setup.config.ucrit) {
                // f = f + alpha * (u - ucrit ) / _DP;
                _l.f = _l.f + _setup.config.alpha * (_u - _setup.config.ucrit) / _DP;
            }
        }

        // todo negative factor
        // x = rmin * T + f * x / _DP;
        _l.x = _setup.config.rmin * _l.T + _l.f * _l.x / _DP;

        if (_l.x > X_MAX) {
            didOverflow = true;
            _l.x = X_MAX;
        }

        rcomp = _l.x.exp() - _DP;

        if (rcomp > R_COMPOUND_MAX_PER_SECOND * _l.T) {
            didCap = true;
            rcomp = R_COMPOUND_MAX_PER_SECOND * _l.T;
        }

        _l.assetsAmount = _totalDeposits > _totalBorrowAmount ? _totalDeposits : _totalBorrowAmount;
        
        if (_l.assetsAmount > AMT_MAX) {
            didOverflow = true;
            rcomp = 0;
            k = _setup.config.kmin;

            return (rcomp, k, didOverflow, didCap);
        }

        // log2(((365 * 24 * 3600) * 100) * ((2^255 - 1) / (2 ^16 * 10^18)) * 100 * 10 ^ 18 /  (365 * 24 * 3600)) < 253
        _l.interest = _totalBorrowAmount * rcomp / _DP;

        if (_l.assetsAmount + _l.interest > AMT_MAX) {
            didOverflow = true;
            _l.interest = AMT_MAX - _l.assetsAmount;

            if (_totalBorrowAmount == 0) {
                rcomp = 0;
            } else {
                rcomp = _l.interest * _DP / _totalBorrowAmount;
            }
        }

        if (didOverflow || didCap) {
            k = _setup.config.kmin;
        }


        /*
        // rcomp = exp (x) - DP;
        if (_l.x > X_MAX) {
            rcomp = R_COMPOUND_MAX_PER_SECOND * _l.T;
            didOverflow = true;
        } else {
            rcomp = _l.x.exp() - _DP;
        }

        if (rcomp > R_COMPOUND_MAX_PER_SECOND * _l.T) {
            // capped
            didCap = true;
            rcomp = R_COMPOUND_MAX_PER_SECOND * _l.T;
            k = _setup.config.kmin;
        }

        if (type(int256).max / rcomp < _totalBorrowAmount) {
            // true overflow
            didOverflow = true;
            rcomp = R_COMPOUND_MAX_PER_SECOND * _l.T;
            k = _setup.config.kmin;
            return (rcomp, k, didOverflow, didCap);
        }

        //todo amt max
        if (type(int256).max - _totalBorrowAmount * rcomp / _DP < _totalBorrowAmount) {
            didOverflow = true;
            // interest / tba
            rcomp = 0;
            k = _setup.config.kmin;
            return (rcomp, k, didOverflow, didCap);
        }*/
    }
    // ***
    // function currentInterestRate(uint256 _t0, uint256 _t1, uint256 _k, uint256 _u)
    //     public
    //     pure
    //     returns (uint256 rcur)
    // {
    //     // uint T = t1 - t0;
    //     if (_t1 <= _t0) revert InvalidTimestamp();
    // }

    // /// @dev get compound interest rate
    // /// @param _silo address of Silo for which interest rate should be calculated
    // /// @param _blockTimestamp current block timestamp
    // /// @return rcomp compounded interest rate from last update until now (1e18 == 100%)
    // function getCompoundInterestRate(address _silo, uint256 _blockTimestamp) external view returns (uint256 rcomp) {

    // }

    // /// @dev get current annual interest rate
    // /// @param _silo address of Silo for which interest rate should be calculated
    // /// @param _blockTimestamp current block timestamp
    // /// @return rcur current annual interest rate (1e18 == 100%)
    // function getCurrentInterestRate(address _silo, uint256 _blockTimestamp) external view returns (uint256 rcur) {

    // }
}

// solhint-enable var-name-mixedcase
