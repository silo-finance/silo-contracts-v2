// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IDynamicKinkModelConfig} from "../../interfaces/IDynamicKinkModelConfig.sol";
import {IDynamicKinkModel} from "../../interfaces/IDynamicKinkModel.sol";

/// @title InterestRateModelV2Config
/// @notice Please never deploy config manually, always use factory, because factory does necessary checks.
contract DynamicKinkModelConfig is IDynamicKinkModelConfig {
    int256 internal immutable _ULOW;
    int256 internal immutable _U1;
    int256 internal immutable _U2;
    int256 internal immutable _UCRIT;
    int256 internal immutable _RMIN;
    int256 internal immutable _KMIN;
    int256 internal immutable _KMAX;
    int256 internal immutable _ALPHA;
    int256 internal immutable _CMINUS;
    int256 internal immutable _CPLUS;
    int256 internal immutable _C1;
    int256 internal immutable _C2;
    int256 internal immutable _DMAX;

    constructor(IDynamicKinkModel.Config memory _config) {
        _ULOW = _config.ulow;
        _U1 = _config.u1;
        _U2 = _config.u2;
        _UCRIT = _config.ucrit;
        _RMIN = _config.rmin;
        _KMIN = _config.kmin;
        _KMAX = _config.kmax;
        _ALPHA = _config.alpha;
        _CMINUS = _config.cminus;
        _CPLUS = _config.cplus;
        _C1 = _config.c1;
        _C2 = _config.c2;
        _DMAX = _config.dmax;
    }

    /// @inheritdoc IDynamicKinkModelConfig
    function getConfig() external view virtual returns (IDynamicKinkModel.Config memory config) {
        config.ulow = _ULOW;
        config.u1 = _U1;
        config.u2 = _U2;
        config.ucrit = _UCRIT;
        config.rmin = _RMIN;
        config.kmin = _KMIN;
        config.kmax = _KMAX;
        config.alpha = _ALPHA;
        config.cminus = _CMINUS;
        config.cplus = _CPLUS;
        config.c1 = _C1;
        config.c2 = _C2;
        config.dmax = _DMAX;
    }
}
