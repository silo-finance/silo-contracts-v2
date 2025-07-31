// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SafeCast} from "openzeppelin5/utils/math/SafeCast.sol";

import {Ownable1and2Steps} from "common/access/Ownable1and2Steps.sol";

import {PRBMathSD59x18} from "../../lib/PRBMathSD59x18.sol";
import {ISilo} from "../../interfaces/ISilo.sol";
import {ISiloConfig} from "../../interfaces/ISiloConfig.sol";
import {IDynamicKinkModel} from "../../interfaces/IDynamicKinkModel.sol";
import {IDynamicKinkModelConfig} from "../../interfaces/IDynamicKinkModelConfig.sol";

import {DynamicKinkModelConfig} from "./DynamicKinkModelConfig.sol";

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


TODO try to remove overflow checks
TODO set 5000% but then json tests needs to be adjusted

*/

/// @title DynamicKinkModel
/// @notice Refer to Silo DynamicKinkModel paper for more details.
/// @dev it follows `IInterestRateModel` interface except `initialize` method
/// @custom:security-contact security@silo.finance
contract DynamicKinkModel is IDynamicKinkModel, Ownable1and2Steps {
    /// @dev DP in 18 decimal points used for integer calculations
    int256 internal constant _DP = int256(1e18);

    /// @dev universal limit for several DynamicKinkModel config parameters. Follow the model whitepaper for more
    ///     information. Units of measure are vary per variable type. Any config within these limits is considered
    ///     valid.
    int256 public constant UNIVERSAL_LIMIT = 1e9 * _DP;

    /// @dev maximum value of current interest rate the model will return. This is 10,000% APR in 18-decimals.
    int256 public constant RCUR_CAP = 100 * _DP;

    /// @dev seconds per year used in interest calculations.
    int256 public constant ONE_YEAR = 365 days;

    /// @dev maximum value of compound interest per second the model will return. This is per-second rate.
    int256 public constant RCOMP_CAP = RCUR_CAP / ONE_YEAR;

    /// @dev the time limit for compounding interest. If the 100 years is exceeded, time since last transaction
    ///     is capped to this limit.
    int256 public constant HUNDRED_YEARS = 100 * ONE_YEAR;

    /// @dev maximum exp() input to prevent an overflow.
    int256 public constant X_MAX = 11 * _DP;

    /// @dev maximum value for total borrow amount, total deposits amount and compounded interest. If these
    /// values are above the threshold, compounded interest is reduced to prevent an overflow.
    /// value = type(uint256).max / uint256(2 ** 16 * _DP);
    int256 public constant AMT_MAX = 1766847064778384329583297500742918515827483896875618958;

    /// @dev each Silo setup is stored separately in mapping, that's why we do not need to clone IRM
    /// at the same time this is safety feature because we will write to this mapping based on msg.sender
    mapping(address silo => Setup irmStorage) internal _getSetup;

    /// @dev Config for the model
    IDynamicKinkModelConfig public irmConfig;

    constructor() Ownable1and2Steps(address(0xdead)) {
        // lock the implementation
        _transferOwnership(address(0));
    }

    // TODO it would help if we can have silo as argument
    function initialize(IDynamicKinkModel.Config calldata _config, address _initialOwner) external virtual {
        if (_initialOwner == address(0)) {
            // allow owner to be empty only if config is empty
            IDynamicKinkModel.Config memory empty;
            require(keccak256(abi.encode(empty)) == keccak256(abi.encode(_config)), MissingOwner());
        }

        _deployConfig(_config);
        _transferOwnership(_initialOwner);

        emit Initialized(_initialOwner);
    }

    // TODO is it safe to allow to provide silo as input? it is per silo anyway, 
    // but maybe we can find a way to not pass it
    function updateSetup(ISilo _silo, IDynamicKinkModel.Config calldata _config, int256 _k)
        external
        onlyOwner
    {
        _updateSetup(_silo, _config, _k);
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
        // assume that caller is Silo
        address silo = msg.sender;

        (Setup memory currentSetup, Config memory cfg) = getSetup(silo);

        (int256 rcompInt, int256 k,,) = compoundInterestRate({
            _cfg: cfg,
            _setup: currentSetup,
            _t0: SafeCast.toInt256(_interestRateTimestamp),
            _t1: SafeCast.toInt256(block.timestamp),
            _u: currentSetup.u,
            _td: SafeCast.toInt256(_collateralAssets),
            _tba: SafeCast.toInt256(_debtAssets)
        });

        rcomp = SafeCast.toUint256(rcompInt);

        _updateState(k, _collateralAssets, _debtAssets);
    }

    function getSetup(address _silo) public view returns (Setup memory s, Config memory c) {
        c = irmConfig.getConfig();
        s = _getSetup[_silo];

        if (!s.initialized) s.k = c.kmin;
    }

    function getCompoundInterestRate(address _silo, uint256 _blockTimestamp)
        external
        view
        virtual
        returns (uint256 rcomp)
    {
        ISilo.UtilizationData memory data = ISilo(_silo).utilizationData();
        (Setup memory currentSetup, Config memory cfg) = getSetup(_silo);

        try this.compoundInterestRate({
            _cfg: cfg,
            _setup: currentSetup,
            _t0: SafeCast.toInt256(data.interestRateTimestamp),
            _t1: SafeCast.toInt256(_blockTimestamp),
            _u: currentSetup.u,
            _td: SafeCast.toInt256(data.collateralAssets),
            _tba: SafeCast.toInt256(data.debtAssets)
        }) returns (int256 rcompInt, int256, bool, bool) {
            rcomp = SafeCast.toUint256(rcompInt);
        } catch {
            rcomp = SafeCast.toUint256(RCOMP_CAP);
        }
    }

    function getCurrentInterestRate(address _silo, uint256 _blockTimestamp)
        external
        view
        returns (uint256 rcur)
    {
        ISilo.UtilizationData memory data = ISilo(_silo).utilizationData();
        (Setup memory currentSetup, Config memory cfg) = getSetup(_silo);

        try this.currentInterestRate({
            _cfg: cfg,
            _setup: currentSetup,
            _t0: SafeCast.toInt256(data.interestRateTimestamp),
            _t1: SafeCast.toInt256(_blockTimestamp),
            _td: SafeCast.toInt256(data.collateralAssets),
            _tba: SafeCast.toInt256(data.debtAssets)
        }) returns (int256 rcurInt, bool, bool) {
            rcur = SafeCast.toUint256(rcurInt);
        } catch {
            rcur = SafeCast.toUint256(RCUR_CAP);
        }
    }

    /// @inheritdoc IDynamicKinkModel
    function verifyConfig(IDynamicKinkModel.Config memory _config) public view virtual {
        require(_config.ulow >= 0 && _config.ulow <= _DP, InvalidUlow());
        require(_config.u1 >= 0 && _config.u1 <= _DP, InvalidU1());
        require(_config.u2 >= _config.u1 && _config.u2 <= _DP, InvalidU2());
        require(_config.ucrit >= _config.ulow && _config.ucrit <= _DP, InvalidUcrit());
        require(_config.rmin >= 0 && _config.rmin <= _DP, InvalidRmin());
        require(_config.kmin >= 0 && _config.kmin <= UNIVERSAL_LIMIT, InvalidKmin());
        require(_config.kmax >= _config.kmin && _config.kmin <= UNIVERSAL_LIMIT, InvalidKmax());
        require(_config.alpha >= 0 && _config.alpha <= UNIVERSAL_LIMIT, InvalidAlpha());
        require(_config.cminus >= 0 && _config.cminus <= UNIVERSAL_LIMIT, InvalidCminus());
        require(_config.cplus >= 0 && _config.cplus <= UNIVERSAL_LIMIT, InvalidCplus());
        require(_config.c1 >= 0 && _config.c1 <= UNIVERSAL_LIMIT, InvalidC1());
        require(_config.c2 >= 0 && _config.c2 <= UNIVERSAL_LIMIT, InvalidC2());
        // TODO do we still need upper limit
        require(_config.dmax >= _config.c2 && _config.dmax < UNIVERSAL_LIMIT, InvalidDmax());
    }

    /// @inheritdoc IDynamicKinkModel
    function currentInterestRate( // solhint-disable-line function-max-lines, code-complexity
        Config memory _cfg,
        Setup memory _setup, 
        int256 _t0, 
        int256 _t1,
        int256 _td,
        int256 _tba
    )
        public
        pure
        returns (int256 rcur, bool overflow, bool capped)
    {
        if (_tba == 0) return (0, false, false); // no debt, no interest

        // _t0 < _t1 checks are included inside this function, may revert 
        (,, overflow, capped) = compoundInterestRate({
            _cfg: _cfg,
            _setup: _setup,
            _t0: _t0,
            _t1: _t1,
            _u: _setup.u,
            _td: _td,
            _tba: _tba
        });

        if (overflow) {
            return (0, overflow, capped);
        }

        unchecked {
            int256 T = _t1 - _t0;

            if (T > HUNDRED_YEARS) {
                // TODO if we dont care about overflow, remove
                T = HUNDRED_YEARS;
            }

            // TODO we changing `k` in `compoundInterestRate`, should we use it here, or we using `_setup.k`?
            int256 k = _max(_cfg.kmin, _min(_cfg.kmax, _setup.k));

            if (_setup.u < _cfg.u1) {
                k = _max(
                    k - (_cfg.c1 + _cfg.cminus * (_cfg.u1 - _setup.u) / _DP) * T,
                    _cfg.kmin
                );
            } else if (_setup.u > _cfg.u2) {
                k = _min(
                    k + _min(
                        _cfg.c2 + _cfg.cplus * (_setup.u - _cfg.u2) / _DP,
                        _cfg.dmax
                    ) * T,
                    _cfg.kmax
                );
            }

            // additional interest rate
            if (_setup.u >= _cfg.ulow) {
                rcur = _setup.u - _cfg.ulow;

                if (_setup.u >= _cfg.ucrit) {
                    rcur = rcur + _cfg.alpha * (_setup.u - _cfg.ucrit) / _DP;
                }

                rcur = rcur * k / _DP;
            }

            rcur = _min((rcur + _cfg.rmin) * ONE_YEAR, RCUR_CAP);

            // TODO whitepapar says: if the current interest rate (rcur) is above the cap, 
            // value is capped and k is reset to kmin but we only reset k if overflow 
            // or capped in compoundInterestRate, should we do it here? and then return k and save.
        }
    }

    /// @inheritdoc IDynamicKinkModel
    function compoundInterestRate( // solhint-disable-line code-complexity, function-max-lines
        Config memory _cfg,
        Setup memory _setup, 
        int256 _t0,
        int256 _t1, 
        int256 _u,
        int256 _td,
        int256 _tba
    )
        public
        pure
        returns (int256 rcomp, int256 k, bool overflow, bool capped)
    {
        if (_tba == 0) return (0, _setup.k, false, false); // no debt, no interest

        LocalVarsRCOMP memory _l;

        if (_t1 < _t0) revert InvalidTimestamp(); // TODO remove if ok to overflow

        _l.T = _t1 - _t0;

        if (_l.T > HUNDRED_YEARS) {
            _l.T = HUNDRED_YEARS;
        }

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

        // limit x, so the exp() function will not overflow
        if (_l.x > X_MAX) {
            overflow = true;
            _l.x = X_MAX;
        }

        rcomp = PRBMathSD59x18.exp(_l.x) - _DP;

        // limit rcomp
        if (rcomp > RCOMP_CAP * _l.T) {
            capped = true;
            rcomp = RCOMP_CAP * _l.T;
        }

        _l.amt = _max(_tba, _td);

        // stop compounding interest for critical assets amounts
        // this IF was added in additional to the paper
        // TODO remove if we will remove overflow checks
        if (_l.amt > AMT_MAX) {
            overflow = true;
            rcomp = 0;
            k = _cfg.kmin;

            return (rcomp, k, overflow, capped);
        }

        // TODO add check for overflow, we can still throw here
        _l.interest = _tba * rcomp / _DP;

        // limit accrued interest if it results in critical assets amount
        if (_l.amt > AMT_MAX - _l.interest) {
            overflow = true;
            // it will not underflow because above, we checking `if (_l.amt > AMT_MAX)`
            _l.interest = AMT_MAX - _l.amt;

            if (_tba == 0) {
                rcomp = 0; // tODO if we early return, this will never happen
            } else {
                rcomp = _l.interest * _DP / _tba;
            }
        }

        // reset the k to the min value in overflow and cap cases
        if (overflow || capped) {
            k = _cfg.kmin;
        }
    }

    function _updateState(int256 _k, uint256 _collateralAssets, uint256 _debtAssets) internal {
        // assume that caller is Silo
        address silo = msg.sender;

        _getSetup[silo].k = _k;

        _getSetup[silo].u = _collateralAssets != 0
            ? SafeCast.toInt232(SafeCast.toInt256(_debtAssets * uint256(_DP) / _collateralAssets))
            : SafeCast.toInt232(_DP); // hard rule: utilization in the model should never be above 100%.

        _getSetup[silo].initialized = true;
    }

    function _updateSetup(ISilo _silo, IDynamicKinkModel.Config memory _config, int256 _k) 
        internal 
        returns (IDynamicKinkModelConfig newCfg) 
    {
        require(_k >= _config.kmin && _k <= _config.kmax, InvalidK());

        newCfg = _deployConfig(_config);

        _getSetup[address(_silo)].k = _k; // TODO or we should use config.kmin?
        _getSetup[address(_silo)].initialized = true;

        emit ConfigUpdated(address(_silo), newCfg, _k);
    }


    function _deployConfig(IDynamicKinkModel.Config memory _config) internal returns (IDynamicKinkModelConfig newCfg) {
        verifyConfig(_config);

        newCfg = new DynamicKinkModelConfig(_config);

        irmConfig = newCfg;

        emit NewConfig(newCfg);
    }

    function _min(int256 _a, int256 _b) internal pure returns (int256) {
        return _a < _b ? _a : _b;
    }

    function _max(int256 _a, int256 _b) internal pure returns (int256) {
        return _a > _b ? _a : _b;
    }
}
// solhint-enable var-name-mixedcase
