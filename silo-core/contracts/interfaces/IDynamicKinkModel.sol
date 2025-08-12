// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {IDynamicKinkModelConfig} from "./IDynamicKinkModelConfig.sol";

interface IDynamicKinkModel {
    /// @dev structure that user can provide as input to generage Kink model default config.
    /// @param ulow threshold of low utilization.
    /// @param ucrit threshold of critical utilization.
    /// @param u1 lower bound of optimal utilization range (the model is static while utilization is in this interval).
    /// @param u2 upper bound of optimal utilization range (the model is static while utilization is in this interval).
    /// @param rmin >= 0 – minimal per-second interest rate (minimal APR), active below ulow.
    /// @param rcritMin minimal APR that the model can output at the critical utilization ucrit
    /// @param rcritMax maximal APR that the model can output at the critical utilization ucrit
    /// @param r100 maximal possible APR at 100% utilization
    /// @param t1 time that it takes to drop from the maximal to the minimal APR at utilization u1
    /// @param t2 time that it takes to grow from the minimal to the maximal APR at utilization u2
    /// @param tMinus time that it takes to reset the model from the maximal to the minimal APR when utilization is ulow
    /// @param tPlus time that it takes to grow from the minimal to the maximal APR at utilization ucrit
    /// @param tMin minimal time it takes to grow from the minimal to the maximal APR at any utilization
    struct UserFriendlyConfig {
        uint256 ulow;
        uint256 ucrit;
        uint256 u1;
        uint256 u2;
        uint256 rmin;
        uint256 rcritMin;
        uint256 rcritMax;
        uint256 r100;
        uint256 t1;
        uint256 t2;
        uint256 tMinus;
        uint256 tPlus;
        uint256 tMin;
    }

    /// @dev same as UserFriendlyConfig but with int256 values to help with calculations
    struct UserFriendlyConfigInt {
        int256 ulow;
        int256 ucrit;
        int256 u1;
        int256 u2;
        int256 rmin;
        int256 rcritMin;
        int256 rcritMax;
        int256 r100;
        int256 t1;
        int256 t2;
        int256 tMinus;
        int256 tPlus;
        int256 tMin;
    }

    /// @param ulow ∈ [0, 1) – threshold of low utilization.
    /// @param u1 ∈ [0, 1) – lower bound of optimal utilization range.
    /// @param u2 ∈ [u1, 1] – upper bound of optimal utilization range.
    /// @param ucrit ∈ [ulow, 1] – threshold of critical utilization.
    /// @param rmin >= 0 – minimal per-second interest rate.
    /// @param kmin >= 0 – minimal slope k of central segment of the kink.
    /// @param kmax >= kmin – maximal slope k of central segment of the kink.
    /// @param alpha >= 0 – factor for the slope for the critical segment of the kink.
    /// @param cminus >= 0 – coefficient of decrease of the slope k.
    /// @param cplus >= 0 – growth coefficient of the slope k.
    /// @param c1 >= 0 – minimal rate of decrease of the slope k.
    /// @param c2 >= 0 – minimal growth rate of the slope k.
    /// @param dmax – maximal growth rate of the slope k.
    struct Config {
        int256 ulow;
        int256 u1;
        int256 u2;
        int256 ucrit;
        int256 rmin;
        int96 kmin;
        int96 kmax;
        int256 alpha;
        int256 cminus;
        int256 cplus;
        int256 c1;
        int256 c2;
        int256 dmax;
    }

    /// @param T time since the last transaction.
    /// @param k1 internal variable for slope calculations.
    /// @param f factor for the slope in kink.
    /// @param roc internal variable for slope calculations.
    /// @param x internal variable for slope calculations.
    /// @param interest absolute value of compounded interest.
    struct LocalVarsRCOMP {
        int256 T;
        int256 k1;
        int256 f;
        int256 roc;
        int256 x;
        int256 interest;
    }

    /// @param k state of the slope after latest interest rate accrual.
    /// @param silo silo address for which model is created.
    struct ModelState {
        int96 k;
        address silo;
    }

    event Initialized(address indexed owner, address indexed silo);

    event NewConfig(IDynamicKinkModelConfig indexed config);

    event ConfigUpdated(IDynamicKinkModelConfig indexed config);

    event ConfigRestored(IDynamicKinkModelConfig indexed config);

    error OnlySilo();
    error InvalidSilo();
    error InvalidDefaultConfig();
    error AddressZero();
    error NotInitialized();
    error AlreadyInitialized();
    error InvalidUlow();
    error InvalidU1();
    error InvalidU2();
    error InvalidUcrit();
    error InvalidRmin();
    error InvalidRcritMin();
    error InvalidRcritMax();
    error InvalidK();
    error InvalidKmin();
    error InvalidKmax();
    error InvalidAlpha();
    error InvalidCminus();
    error InvalidCplus();
    error InvalidC1();
    error InvalidC2();
    error InvalidDmax();
    error InvalidTMin();
    error InvalidT1();
    error InvalidT2();
    error InvalidTMinus();
    error InvalidTPlus();
    error XOverflow();

    function initialize(IDynamicKinkModel.Config calldata _config, address _initialOwner, address _silo) external;

    /// @notice Check if variables in config match the limits from model whitepaper.
    /// Some limits are narrower than in whhitepaper, because of additional research, see:
    /// https://silofinance.atlassian.net/wiki/spaces/SF/pages/347963393/DynamicKink+model+config+limits+V1
    /// @dev it throws when config is invalid
    /// @param _config DynamicKinkModel config struct, does not include the state of the model.
    function verifyConfig(IDynamicKinkModel.Config calldata _config) external view;

    /// @notice Calculate compound interest rate, refer model whitepaper for more details.
    /// @param _cfg Config config struct with model configuration.
    /// @param _setup DynamicKinkModel config struct with model state.
    /// @param _t0 timestamp of the last interest rate update.
    /// @param _t1 timestamp of the compounded interest rate calculations (current time).
    /// @param _u utilization ratio of silo and asset at _t0
    /// @param _tba total borrow amount at _t1.
    /// @return rcomp compounded interest in decimal points.
    /// @return k new state of the model at _t1
    function compoundInterestRate(
        Config memory _cfg,
        ModelState memory _setup,
        int256 _t0,
        int256 _t1,
        int256 _u,
        int256 _tba
    )
        external
        pure
        returns (int256 rcomp, int256 k);

    /// @notice Calculate current interest rate, refer model whitepaper for more details.
    /// @param _cfg Config config struct with model configuration.
    /// @param _setup DynamicKinkModel config struct with model state.
    /// @param _t0 timestamp of the last interest rate update.
    /// @param _t1 timestamp of the current interest rate calculations (current time).
    /// @param _u utilization ratio of silo and asset at _t1.
    /// @param _tba total borrow amount at _t1.
    /// @return rcur current interest in decimal points.
    function currentInterestRate(
        Config memory _cfg,
        ModelState memory _setup,
        int256 _t0,
        int256 _t1,
        int256 _u,
        int256 _tba
    )
        external
        pure
        returns (int256 rcur);
}
