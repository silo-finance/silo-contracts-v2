// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {SafeCast} from "openzeppelin-contracts/utils/math/SafeCast.sol";
import {Math} from "openzeppelin-contracts/utils/math/Math.sol";

import {PRBMathSD59x18} from "../lib/PRBMathSD59x18.sol";
import {EasyMathV2} from  "../lib/EasyMathV2.sol";
import {ISilo} from "../interfaces/ISilo.sol";
import {IInterestRateModel} from "../interfaces/IInterestRateModel.sol";
import {IInterestRateModelConfig} from "../interfaces/IInterestRateModelConfig.sol";

/* solhint-disable var-name-mixedcase */

/// @title InterestRateModelV2
/// @notice This model is for one silo/asset set. So one silo need to have as many IRMs as many assets it holds.
/// @dev Model stores some Silo specific data. If model is replaced, it needs to set proper config after redeployment
/// for seamless service. Please refer to separate litepaper about model for design details.
/// Difference between original `InterestRateModel` is that we made methods to be `virtual` and :
///     if (_config.ki < 0) revert InvalidKi();  --- was ... <= 0
//      if (_config.kcrit < 0) revert InvalidKcrit();  --- was ... <= 0
/// @custom:security-contact security@silo.finance
contract InterestRateModelV2 is IInterestRateModel {
    using PRBMathSD59x18 for int256;
    using SafeCast for int256;
    using SafeCast for uint256;

    struct LocalRiTcrit {
        int256 ri;
        int256 Tcrit;
    }

    struct LocalVarsRCur {
        int256 T;
        int256 u;
        int256 DP;
        int256 rp;
        int256 rlin;
        int256 ri;
        bool overflow;
    }

    struct LocalVarsRComp {
        int256 T;
        int256 slopei;
        int256 rp;
        int256 slope;
        int256 r0;
        int256 rlin;
        int256 r1;
        int256 x;
        int256 rlin1;
        int256 u;
    }

    /// @dev DP is 18 decimal points used for integer calculations
    uint256 public constant override DP = 1e18;

    /// @dev maximum value of compound interest the model will return
    uint256 public constant RCOMP_MAX = (2**16) * 1e18;

    /// @dev maximum value of X for which, RCOMP_MAX should be returned. If x > X_MAX => exp(x) > RCOMP_MAX.
    /// X_MAX = ln(RCOMP_MAX + 1)
    int256 public constant X_MAX = 11090370147631773313;

    /// @dev maximum allowed amount for accruedInterest, totalDeposits and totalBorrowedAmount
    /// after adding compounded interest. If rcomp cause this values to overflow, rcomp is reduced.
    /// 196 bits max allowed for an asset amounts because the multiplication product with
    /// decimal points (10^18) should not cause an overflow. 196 < log2(2^256 / 10^18)
    uint256 public constant ASSET_DATA_OVERFLOW_LIMIT = 2**196;

    /// @dev each Silo setup is stored separately in mapping, that's why we do not need to clone IRM
    /// at the same time this is safety feature because we will write to this mapping based on msg.sender
    /// silo => asset => setup
    mapping (address => mapping (address => Setup)) public getSetup;

    /// @notice Emitted on config init
    /// @param silo Silo address for which config should be set
    /// @param asset asset address for which config should be set
    /// @param config config struct for asset in Silo
    event Initialized(address indexed silo, address indexed asset, address indexed config);

    function connect(address _asset, address _configAddress) external virtual {
        if (_asset == address(0)) revert AddressZero();
        if (address(getSetup[msg.sender][_asset].config) != address(0)) revert AlreadyConnected();

        getSetup[msg.sender][_asset].config = IInterestRateModelConfig(_configAddress);
        emit Initialized(msg.sender, _asset, _configAddress);
    }

    /// @inheritdoc IInterestRateModel
    function getCompoundInterestRateAndUpdate(
        address _asset,
        uint256 _blockTimestamp
    ) external virtual override returns (uint256 rcomp) {
        // assume that caller is Silo
        address silo = msg.sender;

        ISilo.UtilizationData memory data = ISilo(silo).utilizationData(_asset);

        // TODO when depositing, we doing two calls for `calculateCompoundInterestRate`, maybe we can optimize?
        Setup storage currentSetup = getSetup[silo][_asset];

        (rcomp, currentSetup.ri, currentSetup.Tcrit) = calculateCompoundInterestRate(
            getConfig(silo, _asset),
            data.totalDeposits,
            data.totalBorrowAmount,
            data.interestRateTimestamp,
            _blockTimestamp
        );
    }

    /// @inheritdoc IInterestRateModel
    function getCompoundInterestRate(
        address _silo,
        address _asset,
        uint256 _blockTimestamp
    ) external view virtual override returns (uint256 rcomp) {
        ISilo.UtilizationData memory data = ISilo(_silo).utilizationData(_asset);

        (rcomp,,) = calculateCompoundInterestRate(
            getConfig(_silo, _asset),
            data.totalDeposits,
            data.totalBorrowAmount,
            data.interestRateTimestamp,
            _blockTimestamp
        );
    }

    /// @inheritdoc IInterestRateModel
    function overflowDetected(
        address _silo,
        address _asset,
        uint256 _blockTimestamp
    ) external view virtual override returns (bool overflow) {
        ISilo.UtilizationData memory data = ISilo(_silo).utilizationData(_asset);

        (,,,overflow) = calculateCompoundInterestRateWithOverflowDetection(
            getConfig(_silo, _asset),
            data.totalDeposits,
            data.totalBorrowAmount,
            data.interestRateTimestamp,
            _blockTimestamp
        );
    }

    /// @inheritdoc IInterestRateModel
    function getCurrentInterestRate(
        address _silo,
        address _asset,
        uint256 _blockTimestamp
    ) external view virtual override returns (uint256 rcur) {
        ISilo.UtilizationData memory data = ISilo(_silo).utilizationData(_asset);

        rcur = calculateCurrentInterestRate(
            getConfig(_silo, _asset),
            data.totalDeposits,
            data.totalBorrowAmount,
            data.interestRateTimestamp,
            _blockTimestamp
        );
    }

    function getConfig(address _silo, address _asset) public view returns (ConfigWithState memory fullConfig) {
        Setup memory setup = getSetup[_silo][_asset];
        Config memory config = setup.config.getConfig();

        fullConfig.uopt = config.uopt;
        fullConfig.ucrit = config.ucrit;
        fullConfig.ulow = config.ulow;
        fullConfig.ki = config.ki;
        fullConfig.kcrit = config.kcrit;
        fullConfig.klow = config.klow;
        fullConfig.klin = config.klin;
        fullConfig.beta = config.beta;
        fullConfig.ri = setup.ri;
        fullConfig.Tcrit = setup.Tcrit;
    }

    /// @inheritdoc IInterestRateModel
    function calculateCurrentInterestRate(
        ConfigWithState memory _c,
        uint256 _totalDeposits,
        uint256 _totalBorrowAmount,
        uint256 _interestRateTimestamp,
        uint256 _blockTimestamp
    ) public pure virtual returns (uint256 rcur) {
        if (_interestRateTimestamp > _blockTimestamp) revert InvalidTimestamps();

        LocalVarsRCur memory _l = LocalVarsRCur(0,0,0,0,0,0,false); // struct for local vars to avoid "Stack too deep"

        (,,,_l.overflow) = calculateCompoundInterestRateWithOverflowDetection(
            _c,
            _totalDeposits,
            _totalBorrowAmount,
            _interestRateTimestamp,
            _blockTimestamp
        );

        if (_l.overflow) {
            return 0;
        }

        // There can't be an underflow in the subtraction because of the previous check
        unchecked {
            // T := t1 - t0 # length of time period in seconds
            _l.T = (_blockTimestamp - _interestRateTimestamp).toInt256();
        }

        _l.u = EasyMathV2.calculateUtilization(DP, _totalDeposits, _totalBorrowAmount).toInt256();
        _l.DP = int256(DP);

        if (_l.u > _c.ucrit) {
            // rp := kcrit *(1 + Tcrit + beta *T)*( u0 - ucrit )
            _l.rp = _c.kcrit * (_l.DP + _c.Tcrit + _c.beta * _l.T) / _l.DP * (_l.u - _c.ucrit) / _l.DP;
        } else {
            // rp := min (0, klow * (u0 - ulow ))
            _l.rp = _min(0, _c.klow * (_l.u - _c.ulow) / _l.DP);
        }

        // rlin := klin * u0 # lower bound between t0 and t1
        _l.rlin = _c.klin * _l.u / _l.DP;
        // ri := max(ri , rlin )
        _l.ri = _max(_c.ri, _l.rlin);
        // ri := max(ri + ki * (u0 - uopt ) * T, rlin )
        _l.ri = _max(_l.ri + _c.ki * (_l.u - _c.uopt) * _l.T / _l.DP, _l.rlin);
        // rcur := max (ri + rp , rlin ) # current per second interest rate
        rcur = (_max(_l.ri + _l.rp, _l.rlin)).toUint256();
        rcur *= 365 days;

        return _currentInterestRateCAP(rcur);
    }

    /// @inheritdoc IInterestRateModel
    function calculateCompoundInterestRate(
        ConfigWithState memory _c,
        uint256 _totalDeposits,
        uint256 _totalBorrowAmount,
        uint256 _interestRateTimestamp,
        uint256 _blockTimestamp
    ) public pure virtual override returns (
        uint256 rcomp,
        int256 ri,
        int256 Tcrit
    ) {
        (rcomp, ri, Tcrit,) = calculateCompoundInterestRateWithOverflowDetection(
            _c,
            _totalDeposits,
            _totalBorrowAmount,
            _interestRateTimestamp,
            _blockTimestamp
        );
    }

    /// @inheritdoc IInterestRateModel
    function calculateCompoundInterestRateWithOverflowDetection( // solhint-disable-line function-max-lines
        ConfigWithState memory _c,
        uint256 _totalDeposits,
        uint256 _totalBorrowAmount,
        uint256 _interestRateTimestamp,
        uint256 _blockTimestamp
    ) public pure virtual returns (
        uint256 rcomp,
        int256 ri,
        int256 Tcrit, // solhint-disable-line var-name-mixedcase
        bool overflow
    ) {
        ri = _c.ri;
        Tcrit = _c.Tcrit;

        // struct for local vars to avoid "Stack too deep"
        LocalVarsRComp memory _l = LocalVarsRComp(0,0,0,0,0,0,0,0,0,0);

        if (_interestRateTimestamp > _blockTimestamp) revert InvalidTimestamps();

        // There can't be an underflow in the subtraction because of the previous check
        unchecked {
            // length of time period in seconds
            _l.T = (_blockTimestamp - _interestRateTimestamp).toInt256();
        }

        int256 _DP = int256(DP); // solhint-disable-line var-name-mixedcase

        _l.u = EasyMathV2.calculateUtilization(DP, _totalDeposits, _totalBorrowAmount).toInt256();

        // slopei := ki * (u0 - uopt )
        _l.slopei = _c.ki * (_l.u - _c.uopt) / _DP;

        if (_l.u > _c.ucrit) {
            // rp := kcrit * (1 + Tcrit) * (u0 - ucrit )
            _l.rp = _c.kcrit * (_DP + Tcrit) / _DP * (_l.u - _c.ucrit) / _DP;
            // slope := slopei + kcrit * beta * (u0 - ucrit )
            _l.slope = _l.slopei + _c.kcrit * _c.beta / _DP * (_l.u - _c.ucrit) / _DP;
            // Tcrit := Tcrit + beta * T
            Tcrit = Tcrit + _c.beta * _l.T;
        } else {
            // rp := min (0, klow * (u0 - ulow ))
            _l.rp = _min(0, _c.klow * (_l.u - _c.ulow) / _DP);
            // slope := slopei
            _l.slope = _l.slopei;
            // Tcrit := max (0, Tcrit - beta * T)
            Tcrit = _max(0, Tcrit - _c.beta * _l.T);
        }

        // rlin := klin * u0 # lower bound between t0 and t1
        _l.rlin = _c.klin * _l.u / _DP;
        // ri := max(ri , rlin )
        ri = _max(ri , _l.rlin);
        // r0 := ri + rp # interest rate at t0 ignoring lower bound
        _l.r0 = ri + _l.rp;
        // r1 := r0 + slope *T # what interest rate would be at t1 ignoring lower bound
        _l.r1 = _l.r0 + _l.slope * _l.T;

        // Calculating the compound interest

        if (_l.r0 >= _l.rlin && _l.r1 >= _l.rlin) {
            // lower bound isn’t activated
            // rcomp := exp (( r0 + r1) * T / 2) - 1
            _l.x = (_l.r0 + _l.r1) * _l.T / 2;
        } else if (_l.r0 < _l.rlin && _l.r1 < _l.rlin) {
            // lower bound is active during the whole time
            // rcomp := exp( rlin * T) - 1
            _l.x = _l.rlin * _l.T;
        } else if (_l.r0 >= _l.rlin && _l.r1 < _l.rlin) {
            // lower bound is active after some time
            // rcomp := exp( rlin *T - (r0 - rlin )^2/ slope /2) - 1
            _l.x = _l.rlin * _l.T - (_l.r0 - _l.rlin)**2 / _l.slope / 2;
        } else {
            // lower bound is active before some time
            // rcomp := exp( rlin *T + (r1 - rlin )^2/ slope /2) - 1
            _l.x = _l.rlin * _l.T + (_l.r1 - _l.rlin)**2 / _l.slope / 2;
        }

        // ri := max(ri + slopei * T, rlin )
        ri = _max(ri + _l.slopei * _l.T, _l.rlin);

        // Checking for the overflow below. In case of the overflow, ri and Tcrit will be set back to zeros. Rcomp is
        // calculated to not make an overflow in totalBorrowedAmount, totalDeposits.
        (rcomp, overflow) = _calculateRComp(_totalDeposits, _totalBorrowAmount, _l.x);

        // if we got a limit for rcomp, we reset Tcrit and Ri model parameters to zeros
        // Resetting parameters will make IR drop from 10k%/year to 100% per year and it will start growing again.
        // If we don’t reset, we will have to wait ~2 weeks to make IR drop (low utilisation ratio required).
        // So zeroing parameters is a only hope for a market to get well again, otherwise it will be almost impossible.
        bool capApplied;

        (rcomp, capApplied) = _compoundInterestRateCAP(rcomp, _l.T.toUint256());

        if (overflow || capApplied) {
            ri = 0;
            Tcrit = 0;
        }
    }

    /// @dev checks for the overflow in rcomp calculations, accruedInterest, totalDeposits and totalBorrowedAmount.
    /// In case of the overflow, rcomp is reduced to make totalDeposits and totalBorrowedAmount <= 2**196.
    function _calculateRComp(
        uint256 _totalDeposits,
        uint256 _totalBorrowAmount,
        int256 _x
    ) internal pure virtual returns (uint256 rcomp, bool overflow) {
        int256 rcompSigned;

        if (_x >= X_MAX) {
            rcomp = RCOMP_MAX;
            // overflow, but not return now. It counts as an overflow to reset model parameters,
            // but later on we can get overflow worse.
            overflow = true;
        } else {
            rcompSigned = _x.exp() - int256(DP);
            rcomp = rcompSigned > 0 ? rcompSigned.toUint256() : 0;
        }

        unchecked {
            // maxAmount = max(_totalDeposits, _totalBorrowAmount) to see
            // if any of this variables overflow in result.
            uint256 maxAmount = _totalDeposits > _totalBorrowAmount ? _totalDeposits : _totalBorrowAmount;

            if (maxAmount >= ASSET_DATA_OVERFLOW_LIMIT) {
                return (0, true);
            }

            uint256 rcompMulTBA = rcomp * _totalBorrowAmount;

            if (rcompMulTBA == 0) {
                return (rcomp, overflow);
            }

            if (
                rcompMulTBA / rcomp != _totalBorrowAmount ||
                rcompMulTBA / DP > ASSET_DATA_OVERFLOW_LIMIT - maxAmount
            ) {
                rcomp = (ASSET_DATA_OVERFLOW_LIMIT - maxAmount) * DP / _totalBorrowAmount;

                return (rcomp, true);
            }
        }
    }

    /// @dev Returns the largest of two numbers
    function _max(int256 a, int256 b) internal pure virtual returns (int256) {
        return a > b ? a : b;
    }

    /// @dev Returns the smallest of two numbers
    function _min(int256 a, int256 b) internal pure virtual returns (int256) {
        return a < b ? a : b;
    }

    /// @dev in order to keep methods pure and bee able to deploy easily new caps,
    /// that method with hardcoded CAP was created
    /// @notice limit for compounding interest rcomp := RCOMP_CAP * _l.T.
    /// The limit is simple. Let’s threat our interest rate model as the black box. And for past _l.T time we got
    /// a value for rcomp. We need to provide the top limit this value to take into account the limit for current
    /// interest. Let’s imagine, if we had maximum allowed interest for _l.T. `RCOMP_CAP * _l.T` will be the value of
    /// rcomp in this case, which will serve as the limit.
    /// If we got this limit, we should make Tcrit and Ri equal to zero, otherwise there is a low probability of the
    /// market going back below the limit.
    function _compoundInterestRateCAP(uint256 _rcomp, uint256 _t)
        internal
        pure
        virtual
        returns (uint256 updatedRcomp, bool capApplied)
    {
        // uint256 cap = 10**20 / (365 * 24 * 3600); // this is per-second rate because _l.T is in seconds.
        uint256 cap = 3170979198376 * _t;
        return _rcomp > cap ? (cap, true) : (_rcomp, false);
    }

    /// @notice limit for rcur - RCUR_CAP (FE/integrations, does not affect our protocol).
    /// This is the limit for current interest rate, we picked 10k% of interest per year. Interest rate model is working
    /// as expected before that threshold and simply sets the maximum value in case of limit.
    /// 10k% is a really significant threshold, which will mean the death of market in most of cases.
    /// Before 10k% interest rate can be good for certain market conditions.
    /// We don’t read the current interest rate in our protocol, because we care only about the interest we compounded
    /// over the past time since the last update. It is used in UI and other protocols integrations,
    /// for example investing strategies.
    function _currentInterestRateCAP(uint256 _rcur) internal pure virtual returns (uint256) {
        uint256 cap = 1e20; // 10**20; this is 10,000% APR in the 18-decimals format.
        return _rcur > cap ? cap : _rcur;
    }
}

/* solhint-enable var-name-mixedcase */
