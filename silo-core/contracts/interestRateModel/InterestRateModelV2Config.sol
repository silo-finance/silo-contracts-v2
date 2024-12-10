// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IInterestRateModelV2Config} from "../interfaces/IInterestRateModelV2Config.sol";
import {IInterestRateModelV2} from "../interfaces/IInterestRateModelV2.sol";

/// @title InterestRateModelV2Config
/// @notice Please never deploy config manually, always use factory, because factory does necessary checks.
contract InterestRateModelV2Config is IInterestRateModelV2Config {
    // uopt ∈ (0, 1) – optimal utilization;
    int256 internal immutable _UOPT;
    // ucrit ∈ (uopt, 1) – threshold of large utilization;
    int256 internal immutable _UCRIT;
    // ulow ∈ (0, uopt) – threshold of low utilization
    int256 internal immutable _ULOW;
    // ki > 0 – integrator gain
    int256 internal immutable _KI;
    // kcrit > 0 – proportional gain for large utilization
    int256 internal immutable _KCRIT;
    // klow ≥ 0 – proportional gain for low utilization
    int256 internal immutable _KLOW;
    // klin ≥ 0 – coefficient of the lower linear bound
    int256 internal immutable _KLIN;
    // beta ≥ 0 - a scaling factor
    int256 internal immutable _BETA;

    // initial value for ri, ri ≥ 0 – initial value of the integrator
    int112 internal immutable _RI;
    // initial value for Tcrit, Tcrit ≥ 0 - the time during which the utilization exceeds the critical value
    int112 internal immutable _TCRIT;

    constructor(IInterestRateModelV2.Config memory _config) {
        _UOPT = _config.uopt;
        _UCRIT = _config.ucrit;
        _ULOW = _config.ulow;
        _KI = _config.ki;
        _KCRIT = _config.kcrit;
        _KLOW = _config.klow;
        _KLIN = _config.klin;
        _BETA = _config.beta;

        _RI = _config.ri;
        _TCRIT = _config.Tcrit;
    }

    /// @inheritdoc IInterestRateModelV2Config
    function getConfig() external view virtual returns (IInterestRateModelV2.Config memory config) {
        config.uopt = _UOPT;
        config.ucrit = _UCRIT;
        config.ulow = _ULOW;
        config.ki = _KI;
        config.kcrit = _KCRIT;
        config.klow = _KLOW;
        config.klin = _KLIN;
        config.beta = _BETA;

        config.ri = _RI;
        config.Tcrit = _TCRIT;
    }
}
