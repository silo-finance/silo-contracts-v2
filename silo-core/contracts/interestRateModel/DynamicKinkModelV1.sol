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

    // returns decimal points used by model
    uint256 public constant DECIMALS = 18;
    /// @dev DP is 18 decimal points used for integer calculations
    int256 internal constant _DP = int256(10 ** DECIMALS);

    /// @dev maximum value of X. If x > X_MAX => exp(x) > (2**16) * 1e18. X_MAX = ln((2**16) * 1e18 + 1)
    int256 public constant X_MAX = 88722839111672999628;

    /// @dev maximum value of current interest rate the model will return. This is 10,000% APR in the 18-decimals format
    int256 public constant R_CURRENT_MAX = 1e20;

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

    /// @dev get compound interest rate
    /// @param _t0 timestamp of last calculation
    /// @param _t1 current timestamp
    /// @param _u utilization at time t0
    /// @return rcomp compounded interest rate
    /// @return k updated state of the slope k at time t1
    function compoundInterestRate(Setup memory _setup, int256 _t0, int256 _t1, int256 _u)
        public
        pure
        returns (int256 rcomp, int256 k)
    {
        // uint T = t1 - t0;
        if (_t1 <= _t0) revert InvalidTimestamp();
        int256 T = _t1 - _t0;

        //todo 
        k = _setup.k;

        // int roc ; // rate of change for k
        int roc;

        // if (u < u1) {
        if (_u < _setup.config.u1) {
            // roc = - c1 - cminus * (u1 - u) / DP;
            roc = - _setup.config.c1 - _setup.config.cminus * (_setup.config.u1 - _u) / _DP;
        // } else if (u > u2) {       
        } else if (_u > _setup.config.u2) {
            // roc = min (c2 + cplus * (u - u2) / DP , dmax );
            roc = _setup.config.c2 + _setup.config.cplus * (_u - _setup.config.u2) / _DP;
            roc = roc > _setup.config.dmax ? _setup.config.dmax : roc;
        } else {
            // todo remove pointless
            roc = 0;
        }

        int256 k1 = k + roc * T; // slope of the kink at t1 ignoring lower and upper bounds

        int256 x; // an integral of k

        // if (k1 > kmax ) {
        if (k1 > _setup.config.kmax) {
            // x = kmax * T - ( kmax - _k)**2 / (2 * roc );
            x = _setup.config.kmax * T - (_setup.config.kmax - k) ** 2 / (2 * roc);
            // k = kmax ;
            k = _setup.config.kmax;
        // } else if (k1 < kmin ) {
        } else if (k1 < _setup.config.kmin) {
            // x = kmin * T - (_k - kmin ) **2 / (2 * roc );
            x = _setup.config.kmin * T - (k - _setup.config.kmin)**2 / (2 * roc);
            // k = kmin ;
            k = _setup.config.kmin;
        } else {
            // x = (_k + k1) * T / 2;
            x = (k + k1) * T / 2;
            // k = k1;
            k = k1;
        }

        int256 f; // factor for the slope in kink
        // if (u >= ulow ) {
        if (_u >= _setup.config.ulow) {
            // f = u - ulow ;
            f = _u - _setup.config.ulow;
            // if (u >= ucrit ) {
            if (_u >= _setup.config.ucrit) {
                // f = f + alpha * (u - ucrit ) / DP;
                f = f + _setup.config.alpha * (_u - _setup.config.ucrit) / _DP;
            }
        }

        // x = rmin * T + f * x / DP;
        x = _setup.config.rmin * T + f * x / _DP;

        // rcomp = exp (x) - DP;
        if (x > X_MAX) {
            rcomp = R_COMPOUND_MAX_PER_SECOND * T;
        } else {
            rcomp = x.exp() - _DP;
        }
    }

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
