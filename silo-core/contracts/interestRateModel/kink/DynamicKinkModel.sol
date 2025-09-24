// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SafeCast} from "openzeppelin5/utils/math/SafeCast.sol";
import {Math} from "openzeppelin5/utils/math/Math.sol";
import {SignedMath} from "openzeppelin5/utils/math/SignedMath.sol";
import {Initializable} from "openzeppelin5/proxy/utils/Initializable.sol";

import {Ownable1and2Steps} from "common/access/Ownable1and2Steps.sol";

import {PRBMathSD59x18} from "../../lib/PRBMathSD59x18.sol";
import {ISilo} from "../../interfaces/ISilo.sol";
import {ISiloConfig} from "../../interfaces/ISiloConfig.sol";
import {IDynamicKinkModel} from "../../interfaces/IDynamicKinkModel.sol";
import {IDynamicKinkModelConfig} from "../../interfaces/IDynamicKinkModelConfig.sol";

import {DynamicKinkModelConfig} from "./DynamicKinkModelConfig.sol";
import {KinkMath} from "../../lib/KinkMath.sol";


/// @title DynamicKinkModel
/// @notice Refer to Silo DynamicKinkModel paper for more details.
/// @dev it follows `IInterestRateModel` interface except `initialize` method
/// @custom:security-contact security@silo.finance
contract DynamicKinkModel is IDynamicKinkModel, Ownable1and2Steps, Initializable {
    using KinkMath for int256;
    using KinkMath for int96;
    using KinkMath for uint256;

    /// @dev DP in 18 decimal points used for integer calculations
    int256 internal constant _DP = int256(1e18);

    /// @dev universal limit for several DynamicKinkModel config parameters. Follow the model whitepaper for more
    ///     information. Units of measure vary per variable type. Any config within these limits is considered
    ///     valid.
    int256 public constant UNIVERSAL_LIMIT = 1e9 * _DP;

    /// @dev maximum value of current interest rate the model will return. This is 2,500% APR in 18-decimals.
    int256 public constant RCUR_CAP = 25 * _DP;

    /// @dev seconds per year used in interest calculations.
    int256 public constant ONE_YEAR = 365 days;

    /// @dev maximum value of compound interest per second the model will return. This is per-second rate.
    int256 public constant RCOMP_CAP_PER_SECOND = RCUR_CAP / ONE_YEAR;

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
        _disableInitializers();
    }

    function initialize(IDynamicKinkModel.Config calldata _config, address _initialOwner, address _silo)
        external
        virtual
        initializer
    {
        require(_silo != address(0), EmptySilo());

        modelState.silo = _silo;

        _updateConfiguration(_config);

        _transferOwnership(_initialOwner);

        emit Initialized(_initialOwner, _silo);
    }

    function updateConfig(IDynamicKinkModel.Config calldata _config) external virtual onlyOwner {
        _updateConfiguration(_config);
    }

    /// @inheritdoc IDynamicKinkModel
    function restoreLastConfig() external virtual onlyOwner {
        IDynamicKinkModelConfig lastOne = configsHistory[irmConfig];
        require(address(lastOne) != address(0), AddressZero());

        irmConfig = lastOne;
        modelState.k = lastOne.getConfig().kmin;
        emit ConfigRestored(lastOne);
    }

    /// @inheritdoc IDynamicKinkModel
    function getCompoundInterestRateAndUpdate(
        uint256 _collateralAssets,
        uint256 _debtAssets,
        uint256 _interestRateTimestamp
    )
        external
        virtual
        returns (uint256 rcomp) 
    {
        (ModelState memory state, Config memory cfg) = getModelStateAndConfig();
        require(msg.sender == state.silo, OnlySilo());

        if (_collateralAssets.willOverflowOnCastToInt256()) return 0;
        if (_debtAssets.willOverflowOnCastToInt256()) return 0;
        if (_interestRateTimestamp.willOverflowOnCastToInt256()) return 0;
        if (block.timestamp.willOverflowOnCastToInt256()) return 0;

        try this.compoundInterestRate({
            _cfg: cfg,
            _state: state,
            _t0: int256(_interestRateTimestamp),
            _t1: int256(block.timestamp),
            _u: _calculateUtiliation(_collateralAssets, _debtAssets),
            _tba: int256(_debtAssets)
        }) returns (int256 rcompInt, int256 k) {
            rcomp = SafeCast.toUint256(rcompInt);
            modelState.k = _capK(k, cfg.kmin, cfg.kmax);
        } catch {
            rcomp = 0;
            modelState.k = cfg.kmin; // k should be set to min on overflow
        }
    }

    /// @inheritdoc IDynamicKinkModel
    function getCompoundInterestRate(address _silo, uint256 _blockTimestamp)
        external
        view
        virtual
        returns (uint256 rcomp)
    {
        (ModelState memory state, Config memory cfg) = getModelStateAndConfig();
        require(_silo == state.silo, InvalidSilo());

        ISilo.UtilizationData memory data = ISilo(_silo).utilizationData();

        if (_blockTimestamp.willOverflowOnCastToInt256()) return 0;
        if (data.debtAssets.willOverflowOnCastToInt256()) return 0;

        try this.compoundInterestRate({
            _cfg: cfg,
            _state: state,
            _t0: int256(uint256(data.interestRateTimestamp)),
            _t1: int256(_blockTimestamp),
            _u: _calculateUtiliation(data.collateralAssets, data.debtAssets),
            _tba: int256(data.debtAssets)
        }) returns (int256 rcompInt, int256) {
            rcomp = SafeCast.toUint256(rcompInt);
        } catch {
            rcomp = 0;
        }
    }

    /// @notice it reverts for invalid silo
    function getCurrentInterestRate(address _silo, uint256 _blockTimestamp)
        external
        view
        virtual
        returns (uint256 rcur)
    {
        (ModelState memory state, Config memory cfg) = getModelStateAndConfig();
        require(_silo == state.silo, InvalidSilo());

        ISilo.UtilizationData memory data = ISilo(state.silo).utilizationData();

        if (data.debtAssets.willOverflowOnCastToInt256()) return 0;
        if (_blockTimestamp.willOverflowOnCastToInt256()) return 0;

        try this.currentInterestRate({
            _cfg: cfg,
            _state: state,
            _t0: SafeCast.toInt256(data.interestRateTimestamp),
            _t1: int256(_blockTimestamp),
            _u: _calculateUtiliation(data.collateralAssets, data.debtAssets),
            _tba: int256(data.debtAssets)
        }) returns (int256 rcurInt) {
            rcur = SafeCast.toUint256(rcurInt);
        } catch {
            rcur = 0;
        }
    }

    /// @inheritdoc IDynamicKinkModel
    function getModelStateAndConfig() public view virtual returns (ModelState memory s, Config memory c) {
        s = modelState;
        c = irmConfig.getConfig();
    }

    // TODO check if we can have static N% always eg by set u == 100% or r min == rmax by using generateConfig()
    // TODO check if we can have static % to 0% always, does not matter what is utiliztion by using generateConfig()
    // TODO developer must be able to generate config from knowing only APR (static).
    

    // TODO update whitepapaer witn <= DP
    /// @inheritdoc IDynamicKinkModel
    function verifyConfig(IDynamicKinkModel.Config memory _config) public view virtual {
        require(_config.ulow.isBetween(0, _DP), InvalidUlow());
        require(_config.u1.isBetween(0, _DP), InvalidU1());
        require(_config.u2.isBetween(_config.u1, _DP), InvalidU2());

        require(_config.ucrit.isBetween(_config.ulow, _DP), InvalidUcrit());

        require(_config.rmin.isBetween(0, _DP), InvalidRmin()); // TODO check if we should use RCOMP_CAP_PER_SECOND instead of _DP

        require(_config.kmin.isBetween(0, UNIVERSAL_LIMIT), InvalidKmin());
        require(_config.kmax.isBetween(_config.kmin, UNIVERSAL_LIMIT), InvalidKmax());

        // we store k as int96, so we double check if it is in the range of int96
        require(_config.kmin.isBetween(0, type(int96).max), InvalidKmin());
        require(_config.kmax.isBetween(_config.kmin, type(int96).max), InvalidKmax());

        require(_config.alpha.isBetween(0, UNIVERSAL_LIMIT), InvalidAlpha());

        require(_config.cminus.isBetween(0, UNIVERSAL_LIMIT), InvalidCminus());
        require(_config.cplus.isBetween(0, UNIVERSAL_LIMIT), InvalidCplus());

        require(_config.c1.isBetween(0, UNIVERSAL_LIMIT), InvalidC1());
        require(_config.c2.isBetween(0, UNIVERSAL_LIMIT), InvalidC2());

        require(_config.dmax.isBetween(_config.c2, UNIVERSAL_LIMIT), InvalidDmax());
    }

    /// @inheritdoc IDynamicKinkModel
    function currentInterestRate( // solhint-disable-line function-max-lines, code-complexity
        Config memory _cfg,
        ModelState memory _state, 
        int256 _t0, 
        int256 _t1,
        int256 _u,
        int256 _tba
    )
        public
        pure
        virtual
        returns (int256 rcur)
    {
        if (_tba == 0) return 0; // no debt, no interest
        
        int256 T = _t1 - _t0;

        // k is stored capped, so we can use it as is
        int256 k = _state.k;

        if (_u < _cfg.u1) {
            k = SignedMath.max(k - (_cfg.c1 + _cfg.cminus * (_cfg.u1 - _u) / _DP) * T, _cfg.kmin);
        } else if (_u > _cfg.u2) {
            k = SignedMath.min(
                k + SignedMath.min(_cfg.c2 + _cfg.cplus * (_u - _cfg.u2) / _DP, _cfg.dmax) * T, _cfg.kmax
            );
        }

        int256 excessU; // additional interest rate
        if (_u >= _cfg.ulow) {
            excessU = _u - _cfg.ulow;

            if (_u >= _cfg.ucrit) {
                excessU = excessU + _cfg.alpha * (_u - _cfg.ucrit) / _DP;
            }

            rcur = excessU * k * ONE_YEAR / _DP + _cfg.rmin * ONE_YEAR;
        } else {
            rcur = _cfg.rmin * ONE_YEAR;
        }

        rcur = SignedMath.min(rcur, RCUR_CAP);
        // TODO add check for negative rcur and return 0
    }

    /// @inheritdoc IDynamicKinkModel
    function compoundInterestRate( // solhint-disable-line code-complexity, function-max-lines
        Config memory _cfg,
        ModelState memory _state, 
        int256 _t0,
        int256 _t1, 
        int256 _u,
        int256 _tba
    )
        public
        pure
        virtual
        returns (int256 rcomp, int256 k)
    {
        // no debt, no interest, overriding min APR
        if (_tba == 0) return (0, _state.k);

        LocalVarsRCOMP memory _l;

        require(_t0 <= _t1, InvalidTimestamp());

        _l.T = _t1 - _t0;
        // if there is no time change, then k should not change
        if (_l.T == 0) return (0, _state.k);

        // rate of change of k
        if (_u < _cfg.u1) {
            _l.roc = -_cfg.c1 - _cfg.cminus * (_cfg.u1 - _u) / _DP;
        } else if (_u > _cfg.u2) {
            _l.roc = SignedMath.min(_cfg.c2 + _cfg.cplus * (_u - _cfg.u2) / _DP, _cfg.dmax);
        }

        k = _state.k;

        // slope of the kink at t1 ignoring lower and upper bounds
        _l.k1 = k + _l.roc * _l.T;

        // calculate the resulting slope state
        if (_l.k1 > _cfg.kmax) {
            _l.x = _cfg.kmax * _l.T - (_cfg.kmax - k) ** 2 / (2 * _l.roc);
            k = _cfg.kmax;
        } else if (_l.k1 < _cfg.kmin) {
            _l.x = _cfg.kmin * _l.T - (k - _cfg.kmin) ** 2 / (2 * _l.roc);
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
        // TODO add check for negative rcomp and return 0

        // limit rcomp
        if (rcomp > RCOMP_CAP_PER_SECOND * _l.T) {
            rcomp = RCOMP_CAP_PER_SECOND * _l.T;
            // k should be set to min only on overflow or cap
            k = _cfg.kmin;
        }

        // TODO update whitepaper and remove oveflow check that we not using
    }

    function _updateConfiguration(IDynamicKinkModel.Config memory _config)
        internal
        virtual
        returns (IDynamicKinkModelConfig newCfg)
    {
        newCfg = _deployConfig(_config);

        modelState.k = _config.kmin;
    }

    function _deployConfig(IDynamicKinkModel.Config memory _config)
        internal
        virtual
        returns (IDynamicKinkModelConfig newCfg)
    {
        verifyConfig(_config);

        newCfg = new DynamicKinkModelConfig(_config); // TODO add info to interface that by setting up same congig we can reset k

        configsHistory[newCfg] = irmConfig;

        irmConfig = newCfg;

        emit NewConfig(newCfg);
    }

    // hard rule: utilization in the model should never be above 100%.
    function _calculateUtiliation(uint256 _collateralAssets, uint256 _debtAssets)
        internal
        pure
        virtual
        returns (int256)
    {
        if (_debtAssets == 0) return 0;
        if (_collateralAssets == 0 || _debtAssets >= _collateralAssets) return _DP;

        return int256(Math.mulDiv(_debtAssets, uint256(_DP), _collateralAssets, Math.Rounding.Floor));
    }

    /// @dev we expect _kmin and _kmax to be in the range of int96
    function _capK(int256 _k, int256 _kmin, int256 _kmax) internal pure virtual returns (int96 cappedK) {
        require(_kmin <= _kmax, InvalidKRange());

        // safe to cast to int96, because we know, that _kmin and _kmax are in the range of int96
        cappedK = int96(SignedMath.max(_kmin, SignedMath.min(_kmax, _k)));
    }
}
