// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SafeCast} from "openzeppelin5/utils/math/SafeCast.sol";
import {Math} from "openzeppelin5/utils/math/Math.sol";

import {Ownable1and2Steps} from "common/access/Ownable1and2Steps.sol";

import {PRBMathSD59x18} from "../../lib/PRBMathSD59x18.sol";
import {ISilo} from "../../interfaces/ISilo.sol";
import {ISiloConfig} from "../../interfaces/ISiloConfig.sol";
import {IDynamicKinkModel} from "../../interfaces/IDynamicKinkModel.sol";
import {IDynamicKinkModelConfig} from "../../interfaces/IDynamicKinkModelConfig.sol";

import {DynamicKinkModelConfig} from "./DynamicKinkModelConfig.sol";
import {KinkMath} from "../../lib/KinkMath.sol";

// solhint-disable var-name-mixedcase

/*
TODO 
QA rules:
- if utilization goes up -> rcomp always go up (unless overflow, then == 0)
- if utilization goes down -> rcomp always go down?
- there should be no overflow when utilization goes down
- function should never throw (unless we will decive to remove uncheck)
- hard rule: utilization (setup.u) in the model should never be above 100%.
- no debt no intrest
- AlreadyInitialized: only one init

TODO set 2500% but then json tests needs to be adjusted

*/

/// @title DynamicKinkModel
/// @notice Refer to Silo DynamicKinkModel paper for more details.
/// @dev it follows `IInterestRateModel` interface except `initialize` method
/// @custom:security-contact security@silo.finance
contract DynamicKinkModel is IDynamicKinkModel, Ownable1and2Steps {
    using KinkMath for int256;

    /// @dev DP in 18 decimal points used for integer calculations
    int256 internal constant _DP = int256(1e18);

    /// @dev universal limit for several DynamicKinkModel config parameters. Follow the model whitepaper for more
    ///     information. Units of measure vary per variable type. Any config within these limits is considered
    ///     valid.
    int256 public constant UNIVERSAL_LIMIT = 1e9 * _DP;

    /// @dev maximum value of current interest rate the model will return. This is 10,000% APR in 18-decimals.
    int256 public constant RCUR_CAP = 100 * _DP;

    /// @dev seconds per year used in interest calculations.
    int256 public constant ONE_YEAR = 365 days;

    /// @dev maximum value of compound interest per second the model will return. This is per-second rate.
    int256 public constant RCOMP_CAP = RCUR_CAP / ONE_YEAR;

    /// @dev maximum exp() input to prevent an overflow.
    int256 public constant X_MAX = 11 * _DP;

    ModelState public modelState;

    /// @dev Map of all configs for the model, used for restoring to last state
    mapping(IDynamicKinkModelConfig current => IDynamicKinkModelConfig prev) public configsHistory;

    /// @dev Config for the model
    IDynamicKinkModelConfig public irmConfig;

    constructor() Ownable1and2Steps(address(0xdead)) {
        // lock the implementation
        _transferOwnership(address(0));
    }

    function initialize(IDynamicKinkModel.Config calldata _config, address _initialOwner, address _silo)
        external
        virtual
    {
        require(modelState.silo == address(0), AlreadyInitialized());
        modelState.silo = _silo;

        _updateConfiguration(_config);

        _transferOwnership(_initialOwner);

        emit Initialized(_initialOwner, _silo);
    }

    function updateSetup(IDynamicKinkModel.Config calldata _config) external onlyOwner {
        _updateConfiguration(_config);
    }

    function restoreLastConfig() external onlyOwner {
        IDynamicKinkModelConfig lastOne = configsHistory[irmConfig];
        require(address(lastOne) != address(0), AddressZero());

        irmConfig = lastOne;
        modelState.k = irmConfig.getConfig().kmin;
    }

    function getCompoundInterestRateAndUpdate(
        uint256 _collateralAssets,
        uint256 _debtAssets,
        uint256 _interestRateTimestamp
    )
        external
        virtual
        returns (uint256 rcomp) 
    {
        (ModelState memory state, Config memory cfg) = getModelState();
        require(msg.sender == state.silo, OnlySilo());

        // TODO whitepapar says: if the current interest rate (rcur) is above the cap,
        // value is capped and k is reset to kmin but we only reset k if overflow
        // or capped in compoundInterestRate, should we do it here? and then return k and save.

        try this.compoundInterestRate({
            _cfg: cfg,
            _setup: state,
            _t0: SafeCast.toInt256(_interestRateTimestamp),
            _t1: SafeCast.toInt256(block.timestamp),
            _u: _calculateUtiliation(_collateralAssets, _debtAssets),
            _tba: SafeCast.toInt256(_debtAssets)
        }) returns (int256 rcompInt, int256 k) {
            rcomp = SafeCast.toUint256(rcompInt);
            modelState.k = k;
        } catch {
            rcomp = 0;
        }
    }

    function getCompoundInterestRate(address _silo, uint256 _blockTimestamp)
        external
        view
        virtual
        returns (uint256 rcomp)
    {
        ISilo.UtilizationData memory data = ISilo(_silo).utilizationData();
        (ModelState memory currentSetup, Config memory cfg) = getModelState();

        try this.compoundInterestRate({
            _cfg: cfg,
            _setup: currentSetup,
            _t0: SafeCast.toInt256(data.interestRateTimestamp),
            _t1: SafeCast.toInt256(_blockTimestamp),
            _u: _calculateUtiliation(data.collateralAssets, data.debtAssets),
            _tba: SafeCast.toInt256(data.debtAssets)
        }) returns (int256 rcompInt, int256) {
            rcomp = SafeCast.toUint256(rcompInt);
        } catch {
            rcomp = 0;
        }
    }

    function getCurrentInterestRate(address _silo, uint256 _blockTimestamp) external view returns (uint256 rcur) {
        (ModelState memory state, Config memory cfg) = getModelState();
        ISilo.UtilizationData memory data = ISilo(state.silo).utilizationData();

        require(_silo == state.silo, InvalidSilo()); // TODO should we return 0?

        try this.currentInterestRate({
            _cfg: cfg,
            _setup: state,
            _t0: SafeCast.toInt256(data.interestRateTimestamp),
            _t1: SafeCast.toInt256(_blockTimestamp),
            _u: _calculateUtiliation(data.collateralAssets, data.debtAssets),
            _tba: SafeCast.toInt256(data.debtAssets)
        }) returns (int256 rcurInt) {
            rcur = SafeCast.toUint256(rcurInt);
        } catch {
            rcur = 0;
        }
    }

    function getModelState() public view returns (ModelState memory s, Config memory c) {
        s = modelState;
        c = irmConfig.getConfig();
    }

    /// @inheritdoc IDynamicKinkModel
    function verifyConfig(IDynamicKinkModel.Config memory _config) public view virtual {
        // 0 <= ulow <= u1 <= u2 <= ucrit <= DP
        require(_config.ulow.isBetween(0, _config.u1), InvalidUlow());
        require(_config.u1.isBetween(_config.ulow, _config.u2), InvalidU1());
        require(_config.u2.isBetween(_config.u1, _config.ucrit), InvalidU2());
        require(_config.ucrit.isBetween(_config.u2, _DP), InvalidUcrit());

        require(_config.rmin.isBetween(0, _DP), InvalidRmin());

        require(_config.kmin.isBetween(0, UNIVERSAL_LIMIT), InvalidKmin());
        require(_config.kmax.isBetween(_config.kmin, UNIVERSAL_LIMIT), InvalidKmax());

        require(_config.alpha.isBetween(0, UNIVERSAL_LIMIT), InvalidAlpha());

        require(_config.cminus.isBetween(0, UNIVERSAL_LIMIT), InvalidCminus());
        require(_config.cplus.isBetween(0, UNIVERSAL_LIMIT), InvalidCplus());

        require(_config.c1.isBetween(0, UNIVERSAL_LIMIT), InvalidC1());
        require(_config.c2.isBetween(0, UNIVERSAL_LIMIT), InvalidC2());

        // TODO do we still need upper limit?
        require(_config.dmax.isBetween(_config.c2, UNIVERSAL_LIMIT), InvalidDmax());
    }

    /// @inheritdoc IDynamicKinkModel
    function currentInterestRate( // solhint-disable-line function-max-lines, code-complexity
        Config memory _cfg,
        ModelState memory _setup, 
        int256 _t0, 
        int256 _t1,
        int256 _u,
        int256 _tba
    )
        public
        pure
        returns (int256 rcur)
    {
        if (_tba == 0) return 0; // no debt, no interest

        // call it to verify if we revert
        // TODO remove it but add rule to echidna that: compoundInterestRate = 0 => currentInterestRate = 0;
        // compoundInterestRate({
        //     _cfg: _cfg,
        //     _setup: _setup,
        //     _t0: _t0,
        //     _t1: _t1,
        //     _u: _u,
        //     _tba: _tba
        // });

        int256 T = _t1 - _t0;

        int256 k = _max(_cfg.kmin, _min(_cfg.kmax, _setup.k));

        if (_u < _cfg.u1) {
            k = _max(
                k - (_cfg.c1 + _cfg.cminus * (_cfg.u1 - _u) / _DP) * T,
                _cfg.kmin
            );
        } else if (_u > _cfg.u2) {
            k = _min(
                k + _min(
                    _cfg.c2 + _cfg.cplus * (_u - _cfg.u2) / _DP,
                    _cfg.dmax
                ) * T,
                _cfg.kmax
            );
        }

        // additional interest rate
        if (_u >= _cfg.ulow) {
            rcur = _u - _cfg.ulow;

            if (_u >= _cfg.ucrit) {
                rcur = rcur + _cfg.alpha * (_u - _cfg.ucrit) / _DP;
            }

            rcur = rcur * k / _DP;
        }

        rcur = _min((rcur + _cfg.rmin) * ONE_YEAR, RCUR_CAP);
    }

    /// @inheritdoc IDynamicKinkModel
    function compoundInterestRate( // solhint-disable-line code-complexity, function-max-lines
        Config memory _cfg,
        ModelState memory _setup, 
        int256 _t0,
        int256 _t1, 
        int256 _u,
        int256 _tba
    )
        public
        pure
        returns (int256 rcomp, int256 k)
    {
        if (_tba == 0) return (0, _setup.k); // no debt, no interest

        LocalVarsRCOMP memory _l;

        _l.T = _t1 - _t0;

        // roc calculations
        if (_u < _cfg.u1) {
            _l.roc = -_cfg.c1 - _cfg.cminus * (_cfg.u1 - _u) / _DP;
        } else if (_u > _cfg.u2) {
            _l.roc = _min(
                _cfg.c2 + _cfg.cplus * (_u - _cfg.u2) / _DP,
                _cfg.dmax
            );
        }

        k = _max(_cfg.kmin, _min(_cfg.kmax, _setup.k));
        // slope of the kink at t1 ignoring lower and upper bounds
        _l.k1 = k + _l.roc * _l.T;

        // calculate the resulting slope state
        if (_l.k1 > _cfg.kmax) {
            _l.x = _cfg.kmax * _l.T - (_cfg.kmax - k) ** 2 / (2 * _l.roc);
            k = _cfg.kmax;
        } else if (_l.k1 < _cfg.kmin) {
            _l.x = _cfg.kmin * _l.T - (_setup.k - _cfg.kmin) ** 2 / (2 * _l.roc);
            k = _cfg.kmin;
        } else {
            _l.x = (k + _l.k1) * _l.T / 2;
            k = _l.k1;
        }

        if (_u >= _cfg.ulow) {
            _l.f = _u - _cfg.ulow;

            if (_u >= _cfg.ucrit) {
                _l.f = _l.f + _cfg.alpha * (_u - _cfg.ucrit) / _DP;
            }
        }

        _l.x = _cfg.rmin * _l.T + _l.f * _l.x / _DP;

        // Overflow Checks

        // limit x, so the exp() function will not overflow, we have unchecked math there
        require(_l.x <= X_MAX, XOverflow());

        rcomp = PRBMathSD59x18.exp(_l.x) - _DP;

        // limit rcomp
        if (rcomp > RCOMP_CAP * _l.T) {
            rcomp = RCOMP_CAP * _l.T;
            k = _cfg.kmin;
        }
    }

    function _updateConfiguration(IDynamicKinkModel.Config memory _config)
        internal
        returns (IDynamicKinkModelConfig newCfg)
    {
        newCfg = _deployConfig(_config);

        modelState.k = _config.kmin;

        emit ConfigUpdated(newCfg);
    }

    function _deployConfig(IDynamicKinkModel.Config memory _config)
        internal
        returns (IDynamicKinkModelConfig newCfg)
    {
        verifyConfig(_config);

        newCfg = new DynamicKinkModelConfig(_config);

        configsHistory[newCfg] = irmConfig;

        irmConfig = newCfg;

        emit NewConfig(newCfg);
    }

    // hard rule: utilization in the model should never be above 100%.
    function _calculateUtiliation(uint256 _collateralAssets, uint256 _debtAssets) internal pure returns (int256) {
        if (_debtAssets == 0) return 0;
        if (_collateralAssets == 0 || _debtAssets >= _collateralAssets) return _DP;

        return int256(Math.mulDiv(_debtAssets, uint256(_DP), _collateralAssets, Math.Rounding.Floor));
    }

    function _min(int256 _a, int256 _b) internal pure returns (int256) {
        return _a < _b ? _a : _b;
    }

    function _max(int256 _a, int256 _b) internal pure returns (int256) {
        return _a > _b ? _a : _b;
    }
}
// solhint-enable var-name-mixedcase
