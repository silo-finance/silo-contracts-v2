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
contract DynamicKinkModelV1 is IInterestRateModel, IDynamicKinkModelV1 {
    using PRBMathSD59x18 for int256;
    using SafeCast for int256;
    using SafeCast for uint256;

    error InvalidTimestamp();

    /// @dev maximum value of current interest rate the model will return
    uint256 internal immutable R_CURRENT_MAX;

    /// @dev maximum value of compound interest per second the model will return
    uint256 internal immutable R_COMPOUND_MAX_PER_SECOND;

    /// @dev DP is 18 decimal points used for integer calculations
    uint256 internal constant _DP = 1e18;

    uint256 public K; // TODO

    /// @dev maximum value of X. If x > X_MAX => exp(x) > (2**16) * 1e18. X_MAX = ln((2**16) * 1e18 + 1)
    int256 public constant X_MAX = 88722839111672999628;

    constructor() {
        R_CURRENT_MAX = 1e20; // this is 10,000% APR in the 18-decimals format
        R_COMPOUND_MAX_PER_SECOND = R_CURRENT_MAX / (365 * 24 * 3600); // this is per-second rate
    }

    /// @dev optional method that can connect silo to it's model state on silo initialization
    /// can be empty by must implement interface.
    function connect(address _configAddress) external;

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
    function compoundInterestRate(ConfigWithState memory _c, uint256 _t0, uint256 _t1, uint256 _u)
        public
        pure
        returns (uint256 rcomp, uint256 k)
    {
        if (_t1 <= _t0) revert InvalidTimestamp();

        k = _c.k;
        uint256 T = _t1 - _t0;
        int256 slope; // rate of change for k

        if (_u >= _c.uopt) {
            slope = _c.cplus * (_u - _c.uopt) / _DP;
        } else {
            slope = - _c.c0 + _c.cminus * (_u - _c.uopt) / _DP;
        }

        int256 k1 = _c.k + slope * T; // slope of the kink at t1 ignoring lower and upper bounds

        uint256 x; // an integral of k

        if (k1 > _c.kmax) {
            x = _c.kmax * T - (_c.kmax - _c.k)**2 / (2 * slope);
            k = _c.kmax;
        } else if (k1 < _c.kmin) {
            x = _c.kmin * T + (k - _c.kmin)**2 / (2 * slope);
            k = _c.kmin;
        } else {
            x = (k + k1) * T / 2;
            k = k1;
        }

        uint256 f; // factor for the slope in kink
        if (_u >= _c.ulow) {
            f = _u - _c.ulow;

            if (_u >= _c.ucrit) {
                f = f + _c.alpha * (_u - _c.ucrit) / _DP;
            }
        }

        x = _c.rmin * T + f * x / _DP;

        if (x > X_MAX) {
            rcomp = R_COMPOUND_MAX_PER_SECOND * T;
        } else {
            rcomp = x.exp() - _DP;
        }
    }

    function currentInterestRate(uint256 _t0, uint256 _t1, uint256 _k, uint256 _u)
        public
        pure
        returns (uint256 rcur)
    {
        // uint T = t1 - t0;
        if (_t1 <= _t0) revert InvalidTimestamp();
    }

    /// @dev get compound interest rate
    /// @param _silo address of Silo for which interest rate should be calculated
    /// @param _blockTimestamp current block timestamp
    /// @return rcomp compounded interest rate from last update until now (1e18 == 100%)
    function getCompoundInterestRate(address _silo, uint256 _blockTimestamp) external view returns (uint256 rcomp);

    /// @dev get current annual interest rate
    /// @param _silo address of Silo for which interest rate should be calculated
    /// @param _blockTimestamp current block timestamp
    /// @return rcur current annual interest rate (1e18 == 100%)
    function getCurrentInterestRate(address _silo, uint256 _blockTimestamp) external view returns (uint256 rcur);

    /// @dev returns decimal points used by model
    function decimals() external view returns (uint256);

    /// @notice limit for compounding interest
    function getRcompMax(uint256 _t) public pure virtual returns (uint256 rcompMax) {
        rcompMax = R_COMPOUND_MAX_PER_SECOND * _t;
    }

    /// @notice limit for current interest
    function getRcurrentMax(uint256 _rcur) public pure virtual returns (uint256 rcurrMax) {
        rcurrMax = R_CURRENT_MAX;
    }
}

// solhint-enable var-name-mixedcase
