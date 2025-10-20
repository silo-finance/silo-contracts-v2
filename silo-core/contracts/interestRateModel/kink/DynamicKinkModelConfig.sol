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
    int96 internal immutable _KMIN;
    int96 internal immutable _KMAX;
    int256 internal immutable _ALPHA;
    int256 internal immutable _CMINUS;
    int256 internal immutable _CPLUS;
    int256 internal immutable _C1;
    int256 internal immutable _C2;
    int256 internal immutable _DMAX;

    uint32 internal immutable _TIMELOCK;
    int96 internal immutable _RCOMP_CAP_PER_SECOND;

    constructor(IDynamicKinkModel.Config memory _config, IDynamicKinkModel.ImmutableConfig memory _immutableConfig) {
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

        _TIMELOCK = _immutableConfig.timelock;
        _RCOMP_CAP_PER_SECOND = _immutableConfig.rcompCapPerSecond;
    }

    /// @inheritdoc IDynamicKinkModelConfig
    function getConfig()
        external
        view
        virtual
        returns (IDynamicKinkModel.Config memory config, IDynamicKinkModel.ImmutableConfig memory immutableConfig)
    {
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

        immutableConfig.timelock = _TIMELOCK;
        immutableConfig.rcompCapPerSecond = _RCOMP_CAP_PER_SECOND;
    }
}
