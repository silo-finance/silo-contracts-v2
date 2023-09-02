// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {IInterestRateModel} from "../interfaces/IInterestRateModel.sol";
import {IInterestRateModelConfig} from "../interfaces/IInterestRateModelConfig.sol";

/// @title InterestRateModelV2Config
/// @notice Please never deploy config manually, always use factory, because factory does necessary checkes.
contract InterestRateModelV2Config is IInterestRateModelConfig {
    // uopt ∈ (0, 1) – optimal utilization;
    int256 internal immutable _UOPT; // solhint-disable-line var-name-mixedcase
    // ucrit ∈ (uopt, 1) – threshold of large utilization;
    int256 internal immutable _UCRIT; // solhint-disable-line var-name-mixedcase
    // ulow ∈ (0, uopt) – threshold of low utilization
    int256 internal immutable _ULOW; // solhint-disable-line var-name-mixedcase
    // ki > 0 – integrator gain
    int256 internal immutable _KI; // solhint-disable-line var-name-mixedcase
    // kcrit > 0 – proportional gain for large utilization
    int256 internal immutable _KCRIT; // solhint-disable-line var-name-mixedcase
    // klow ≥ 0 – proportional gain for low utilization
    int256 internal immutable _KLOW; // solhint-disable-line var-name-mixedcase
    // klin ≥ 0 – coefficient of the lower linear bound
    int256 internal immutable _KLIN; // solhint-disable-line var-name-mixedcase
    // beta ≥ 0 - a scaling factor
    int256 internal immutable _BETA; // solhint-disable-line var-name-mixedcase

    error InvalidBeta();
    error InvalidKcrit();
    error InvalidKi();
    error InvalidKlin();
    error InvalidKlow();
    error InvalidTcrit();
    error InvalidTimestamps();
    error InvalidUcrit();
    error InvalidUlow();
    error InvalidUopt();
    error InvalidRi();

    constructor(IInterestRateModel.Config memory _config) {
        _UOPT = _config.uopt;
        _UCRIT = _config.ucrit;
        _ULOW = _config.ulow;
        _KI = _config.ki;
        _KCRIT = _config.kcrit;
        _KLOW = _config.klow;
        _KLIN = _config.klin;
        _BETA = _config.beta;
    }

    function getConfig() external view virtual returns (IInterestRateModel.Config memory config) {
        config.uopt = _UOPT;
        config.ucrit = _UCRIT;
        config.ulow = _ULOW;
        config.ki = _KI;
        config.kcrit = _KCRIT;
        config.klow = _KLOW;
        config.klin = _KLIN;
        config.beta = _BETA;
    }
}
