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

    error InvalidTimestamp();

    /// @dev DP is 18 decimal points used for integer calculations
    int256 internal constant _DP = 1e18;

    /// @dev maximum value of X. If x > X_MAX => exp(x) > (2**16) * 1e18. X_MAX = ln((2**16) * 1e18 + 1)
    int256 public constant X_MAX = 88722839111672999628;

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
        if (_t1 <= _t0) revert InvalidTimestamp();

        k = _setup.k;
        int256 T = _t1 - _t0;
        int256 slope; // rate of change for k

        // todo uopt -> u1
        if (_u >= _setup.config.u1) {
            slope = _setup.config.cplus * (_u - _setup.config.u1) / _DP;
        } else {
            slope = - _setup.config.c1 + _setup.config.cminus * (_u - _setup.config.u1) / _DP;
        }

        int256 k1 = k + slope * T; // slope of the kink at t1 ignoring lower and upper bounds

        int256 x; // an integral of k

        if (k1 > _setup.config.kmax) {
            x = _setup.config.kmax * T - (_setup.config.kmax - k)**2 / (2 * slope);
            k = _setup.config.kmax;
        } else if (k1 < _setup.config.kmin) {
            x = _setup.config.kmin * T + (k - _setup.config.kmin)**2 / (2 * slope);
            k = _setup.config.kmin;
        } else {
            x = (k + k1) * T / 2;
            k = k1;
        }

        int256 f; // factor for the slope in kink
        if (_u >= _setup.config.ulow) {
            f = _u - _setup.config.ulow;

            if (_u >= _setup.config.ucrit) {
                f = f + _setup.config.alpha * (_u - _setup.config.ucrit) / _DP;
            }
        }

        x = _setup.config.rmin * T + f * x / _DP;

        // if (x > X_MAX) {
        //     rcomp = R_COMPOUND_MAX_PER_SECOND * T;
        // } else {
        //     rcomp = x.exp() - _DP;
        // }
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
    function getCompoundInterestRate(address _silo, uint256 _blockTimestamp) external view returns (uint256 rcomp) {

    }

    /// @dev get current annual interest rate
    /// @param _silo address of Silo for which interest rate should be calculated
    /// @param _blockTimestamp current block timestamp
    /// @return rcur current annual interest rate (1e18 == 100%)
    function getCurrentInterestRate(address _silo, uint256 _blockTimestamp) external view returns (uint256 rcur) {

    }

    /// @dev returns decimal points used by model
    function decimals() external view returns (uint256) {
        return 0;
    }
}

// solhint-enable var-name-mixedcase
