// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {SafeCast} from "openzeppelin-contracts/utils/math/SafeCast.sol";
import {Math} from "openzeppelin-contracts/utils/math/Math.sol";

import {PRBMathSD59x18} from "../lib/PRBMathSD59x18.sol";
import {SiloMathLib} from "../lib/SiloMathLib.sol";
import {ISilo} from "../interfaces/ISilo.sol";
import {IInterestRateModel} from "../interfaces/IInterestRateModel.sol";
import {IInterestRateModelV2} from "../interfaces/IInterestRateModelV2.sol";
import {IInterestRateModelV2Config} from "../interfaces/IInterestRateModelV2Config.sol";

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

    /// @dev maximum value of X. If x > X_MAX => exp(x) > (2**16) * 1e18. X_MAX = ln((2**16) * 1e18 + 1)
    int256 public constant X_MAX = 88722839111672999628;

    struct Config {
        // ucrit ∈ (0, 1) – threshold of critical utilization
        // ulow ∈ (0, ucrit) – threshold of low utilization
        // uopt ∈ (ulow, ucrit) – optimal utilization;
        // rmin ≥ 0 – minimal per-second interest rate
        // kmin ≥ 0 – minimal slope of central segmend of the kink
        // kmax ≥ kmin – maximal slope of central segmend of the kink
        // alpha ≥ 0 - factor for the slope for the critical segment of the kink
        // cplus ≥ 0 – coefficient of growth of the slope k
        // cminus ≥ 0 – coefficient of decrease of the slope k
        // czero ≥ 0 – minimal rate of decrease of the slope k
    }

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
    /// @param _k state of the slope k at time t0
    /// @param _u utilization at time t0
    /// @return rcomp compounded interest rate
    /// @return k updated state of the slope k at time t1
    function compoundInterestRate(uint256 _t0, uint256 _t1, uint256 _k, uint256 _u)
        public
        pure
        returns (uint256 rcomp, uint256 k)
    {
        if (_t1 <= _t0) revert InvalidTimestamp();

        uint256 T = _t1 - _t0;
        int256 slope; // rate of change for k

        if (_u >= uopt) {
            slope = cplus * (_u - uopt) / DP;
        } else {
            slope = - c0 + cminus * (_u - uopt) / DP;
        }

        int256 k1 = _k + slope * T; // slope of the kink at t1 ignoring lower and upper bounds

        uint256 x; // an integral of k

        if (k1 > kmax) {
            x = kmax * T - (kamx - _k)**2 / (2 * slope);
            k = kmax;
        } else if (k1 < kmin) {
            x = kmin * T + (_k - kmin)**2 / (2 * slope);
            k = kmin;
        } else {
            x = (_k + k1) * T / 2;
            k = k1;
        }

        uint256 f; // factor for the slope in kink
        if (u >= ulow) {
            f = u - ulow;

            if (u >= ucrit) {
                f = f + alpha * (u - ucrit) / DP;
            }
        }

        x = rmin * T + f * x / DP;

        if (x > X_MAX) {
            rcomp = R_COMPOUND_MAX_PER_SECOND * T;
        } else {
            rcomp = x.exp() - DP;
        }
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
