// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SafeCast} from "openzeppelin5/utils/math/SafeCast.sol";

import {Ownable1and2Steps} from "common/access/Ownable1and2Steps.sol";

import {PRBMathSD59x18} from "../../lib/PRBMathSD59x18.sol";
import {ISilo} from "../../interfaces/ISilo.sol";
import {ISiloConfig} from "../../interfaces/ISiloConfig.sol";
import {IInterestRateModel} from "../../interfaces/IInterestRateModel.sol";
import {IDynamicKinkModel} from "../../interfaces/IDynamicKinkModel.sol";
import {IDynamicKinkModelConfig} from "../../interfaces/IDynamicKinkModelConfig.sol";

// solhint-disable var-name-mixedcase

/*
TODO 
QA rules:
- if utilization goes up -> rcomp always go up (unless overflow, then == 0)
- if utilization goes down -> rcomp always go down?
- there should be no overflow when utilization goes down
- function should never throw (unless we will decive to remove uncheck)

TODO owner
TODO deployment
TODO try-catch check if possible, use max CAP on catch
TODO try to remove overflow checks
TODO set 5000% but then json tests needs to be adjusted

*/

/// @title DynamicKinkModel
/// @notice Refer to Silo DynamicKinkModel paper for more details.
/// @custom:security-contact security@silo.finance
contract DynamicKinkModel is IInterestRateModel, IDynamicKinkModel, Ownable1and2Steps {
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

    modifier onlySiloDeployer(ISiloConfig _siloConfig) {
        // require(msg.sender == address(irmConfig), "Only config can call this function");
        // TODO
        _;
    }

    constructor() Ownable1and2Steps(msg.sender) {}

    /// @inheritdoc IInterestRateModel
    function initialize(address _irmConfig) external virtual {
        require(_irmConfig != address(0), AddressZero());
        require(address(irmConfig) == address(0), AlreadyInitialized());

        irmConfig = IDynamicKinkModelConfig(_irmConfig);

        emit Initialized(_irmConfig);

        // Ownable2Step._transferOwnership(newOwner);
    }

    function resetConfigToFactorySetup(address _silo) external onlySiloDeployer(ISilo(_silo).config()) {
        _factorySetup(_silo);
    }

    function updateSetup(ISilo _silo, IDynamicKinkModel.Config calldata _config, int256 _k) 
        external 
        onlySiloDeployer(_silo.config()) 
    {
        require(address(irmConfig) != address(0), NotInitialized());
        require(_k >= _config.kmin && _k <= _config.kmax, InvalidK());

        verifyConfig(_config);

        _getSetup[address(_silo)].config = _config; 
        _getSetup[address(_silo)].k = _k; // TODO or we should use config.kmin?

        emit ConfigUpdated(address(_silo), _config, _k);
    }

    /// @inheritdoc IInterestRateModel
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

        Setup memory currentSetup = getSetup(silo);

        if (!currentSetup.initialized) {
            _factorySetup(silo);
        }

        (int256 rcompInt, int256 k,,) = compoundInterestRate({
            _setup: currentSetup,
            _t0: SafeCast.toInt256(_interestRateTimestamp),
            _t1: SafeCast.toInt256(block.timestamp),
            _u: currentSetup.u,
            _td: SafeCast.toInt256(_collateralAssets),
            _tba: SafeCast.toInt256(_debtAssets)
        });

        rcomp = SafeCast.toUint256(rcompInt);

        currentSetup.k = k;

        currentSetup.u = _collateralAssets != 0
            ? SafeCast.toInt232(SafeCast.toInt256(_debtAssets * uint256(_DP) / _collateralAssets))
            : SafeCast.toInt232(_DP); // TODO should we use more for bad debt?

        // TODO do we need cap? check if already applied in compoundInterestRate
    }

    /// @inheritdoc IInterestRateModel
    function getCompoundInterestRate(address _silo, uint256 _blockTimestamp)
        external
        view
        virtual
        returns (uint256 rcomp)
    {
        ISilo.UtilizationData memory data = ISilo(_silo).utilizationData();
        Setup memory currentSetup = getSetup(_silo);

        (int256 rcompInt,,,) = compoundInterestRate({
            _setup: currentSetup,
            _t0: SafeCast.toInt256(data.interestRateTimestamp),
            _t1: SafeCast.toInt256(_blockTimestamp),
            _u: currentSetup.u,
            _td: SafeCast.toInt256(data.collateralAssets),
            _tba: SafeCast.toInt256(data.debtAssets)
        });

        rcomp = SafeCast.toUint256(rcompInt);
    }

    /// @inheritdoc IInterestRateModel
    function getCurrentInterestRate(address _silo, uint256 _blockTimestamp)
        external
        view
        returns (uint256 rcur)
    {
        ISilo.UtilizationData memory data = ISilo(_silo).utilizationData();
        Setup memory currentSetup = getSetup(_silo);

        (int256 rcurInt,,) = currentInterestRate({
            _setup: currentSetup,
            _t0: SafeCast.toInt256(data.interestRateTimestamp),
            _t1: SafeCast.toInt256(_blockTimestamp),
            _u: currentSetup.u,
            _td: SafeCast.toInt256(data.collateralAssets),
            _tba: SafeCast.toInt256(data.debtAssets)
        });

        rcur = SafeCast.toUint256(rcurInt);
    }

    /// @inheritdoc IInterestRateModel
    function decimals() external pure returns (uint256) {
        return 18;
    }

    /// @inheritdoc IDynamicKinkModel
    function verifyConfig(IDynamicKinkModel.Config calldata _config) public view virtual {
        require(_config.ulow >= 0 && _config.ulow < _DP, InvalidUlow());
        require(_config.u1 >= 0 && _config.u1 < _DP, InvalidU1());
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

        // overflow check
        // DynamicKinkModel(IRM).configOverflowCheck(_config); TODO
    }

    function getSetup(address _silo) public view returns (Setup memory setup) {
        setup = _getSetup[_silo];

        if (!setup.initialized) {
            setup.config = irmConfig.getConfig();
            setup.k = setup.config.kmin;
            // `initialized` stays false and `u` we never modify
        }
    }

    /// @inheritdoc IDynamicKinkModel
    function currentInterestRate( // solhint-disable-line function-max-lines
        Setup memory _setup, 
        int256 _t0, 
        int256 _t1, 
        int256 _u,
        int256 _td,
        int256 _tba
    )
        public
        pure
        returns (int256 rcur, bool overflow, bool capped)
    {
        // _t0 < _t1 checks are included inside this function, may revert 
        (,, overflow, capped) = compoundInterestRate({
            _setup: _setup,
            _t0: _t0,
            _t1: _t1,
            _u: _u,
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
            int256 k = _max(_setup.config.kmin, _min(_setup.config.kmax, _setup.k));

            if (_u < _setup.config.u1) {
                k = _max(
                    k - (_setup.config.c1 + _setup.config.cminus * (_setup.config.u1 - _u) / _DP) * T,
                    _setup.config.kmin
                );
            } else if (_u > _setup.config.u2) {
                k = _min(
                    k + _min(
                        _setup.config.c2 + _setup.config.cplus * (_u - _setup.config.u2) / _DP,
                        _setup.config.dmax
                    ) * T,
                    _setup.config.kmax
                );
            }

            // additional interest rate
            if (_u >= _setup.config.ulow) {
                rcur = _u - _setup.config.ulow;

                if (_u >= _setup.config.ucrit) {
                    rcur = rcur + _setup.config.alpha * (_u - _setup.config.ucrit) / _DP;
                }

                rcur = rcur * k / _DP;
            }

            rcur = _min((rcur + _setup.config.rmin) * ONE_YEAR, RCUR_CAP);

            // TODO whitepapar says: if the current interest rate (rcur) is above the cap, value is capped and k is reset to kmin 
            // but we only reset k if overflow or capped in compoundInterestRate, should we do it here? and then return k and save.
        }
    }

    /// @inheritdoc IDynamicKinkModel
    function compoundInterestRate( // solhint-disable-line code-complexity, function-max-lines
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
        LocalVarsRCOMP memory _l;

        unchecked {
            if (_t1 < _t0) revert InvalidTimestamp(); // TODO remove if ok to overflow

            _l.T = _t1 - _t0;

            if (_l.T > HUNDRED_YEARS) {
                _l.T = HUNDRED_YEARS;
            }

            // roc calculations
            if (_u < _setup.config.u1) {
                _l.roc = -_setup.config.c1 - _setup.config.cminus * (_setup.config.u1 - _u) / _DP;
            } else if (_u > _setup.config.u2) {
                _l.roc = _min(
                    _setup.config.c2 + _setup.config.cplus * (_u - _setup.config.u2) / _DP,
                    _setup.config.dmax
                );
            }

            k = _max(_setup.config.kmin, _min(_setup.config.kmax, _setup.k));
            // slope of the kink at t1 ignoring lower and upper bounds
            _l.k1 = k + _l.roc * _l.T;

            // calculate the resulting slope state
            if (_l.k1 > _setup.config.kmax) {
                _l.x = _setup.config.kmax * _l.T - (_setup.config.kmax - k) ** 2 / (2 * _l.roc);
                k = _setup.config.kmax;
            } else if (_l.k1 < _setup.config.kmin) {
                _l.x = _setup.config.kmin * _l.T - (_setup.k - _setup.config.kmin) ** 2 / (2 * _l.roc);
                k = _setup.config.kmin;
            } else {
                _l.x = (k + _l.k1) * _l.T / 2;
                k = _l.k1;
            }

            if (_u >= _setup.config.ulow) {
                _l.f = _u - _setup.config.ulow;

                if (_u >= _setup.config.ucrit) {
                    _l.f = _l.f + _setup.config.alpha * (_u - _setup.config.ucrit) / _DP;
                }
            }

            _l.x = _setup.config.rmin * _l.T + _l.f * _l.x / _DP;

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
            if (_l.amt > AMT_MAX) {
                overflow = true;
                rcomp = 0;
                k = _setup.config.kmin;

                return (rcomp, k, overflow, capped);
            }

            // TODO add check for overflow, we can still throw here
            // TODO should we use mulDiv?
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
                k = _setup.config.kmin;
            }
        }
    }

    function _factorySetup(address _silo) internal {
        require(address(irmConfig) != address(0), NotInitialized());

        IDynamicKinkModel.Config memory config = irmConfig.getConfig();

        _getSetup[address(_silo)].config = config; 
        _getSetup[address(_silo)].k = config.kmin;
        // u is not set here, because at begin is 0, and on future reset it must stay as last value
        _getSetup[address(_silo)].initialized = true;

        emit FactorySetup(address(_silo));
    }

    function _min(int256 _a, int256 _b) internal pure returns (int256) {
        return _a < _b ? _a : _b;
    }

    function _max(int256 _a, int256 _b) internal pure returns (int256) {
        return _a > _b ? _a : _b;
    }
}
// solhint-enable var-name-mixedcase
