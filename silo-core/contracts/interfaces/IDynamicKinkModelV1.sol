// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;


interface IDynamicKinkModelV1 {
    /// @param ulow ∈ [0, 1) – threshold of low utilization.
    /// @param u1 ∈ [0, 1) – lower bound of optimal utilization range.
    /// @param u2 ∈ [u1, 1] – upper bound of optimal utilization range.
    /// @param ucrit ∈ [ulow, 1] – threshold of critical utilization.
    /// @param rmin ⩾ 0 – minimal per-second interest rate.
    /// @param kmin ⩾ 0 – minimal slope k of central segment of the kink.
    /// @param kmax ⩾ kmin – maximal slope k of central segment of the kink.
    /// @param dmax – maximal growth rate of the slope k.
    /// @param alpha ⩾ 0 – factor for the slope for the critical segment of the kink.
    /// @param cminus ⩾ 0 – coefficient of decrease of the slope k.
    /// @param cplus ⩾ 0 – growth coefficient of the slope k.
    /// @param c1 ⩾ 0 – minimal rate of decrease of the slope k.
    /// @param c2 ⩾ 0 – minimal growth rate of the slope k.
    struct Config {
        int256 ulow;
        int256 u1;
        int256 u2;
        int256 ucrit;
        int256 rmin;
        int256 kmin;
        int256 kmax;
        int256 dmax;
        int256 alpha;
        int256 cminus;
        int256 cplus;
        int256 c1;
        int256 c2;
    }

    /// @param T time since the last transaction.
    /// @param k1 internal variable for slope calculations.
    /// @param f factor for the slope in kink.
    /// @param roc internal variable for slope calculations.
    /// @param x internal variable for slope calculations.
    /// @param assetsAmount maximum of total deposits and total borrwed amounts.
    /// @param interest absolute value of compounded interest.
    struct LocalVarsRCOMP {
        int256 T;
        int256 k1;
        int256 f;
        int256 roc;
        int256 x;
        int256 assetsAmount;
        int256 interest;
    }

    /// @param config model parameters for particular silo and asset.
    /// @param k state of the slope after latest interest rate accrual.
    struct Setup {
        Config config;
        int256 k;
    }

    /// @notice Check if variables in config match the limits from model whitepaper.
    /// @param _config DynamicKinkModelV1 config struct, does not include the state of the model.
    /// @return true if the config is valid, false if the config is invalid.
    function validateConfig(Config memory _config) external pure returns (bool);

    /// @notice Calculate compound interest rate, refer model whitepaper for more details.
    /// @param _setup DynamicKinkModelV1 config struct with model state.
    /// @param _t0 timestamp of the last interest rate update.
    /// @param _t1 timestamp of the compounded interest rate calculations (current time).
    /// @param _u utilization ratio of silo and asset at _t1.
    /// @param _totalDeposits total deposits at _t1.
    /// @param _totalBorrowAmount total borrow amount at _t1.
    /// @return rcomp compounded interest in decimal points.
    /// @return k new state of the model.
    /// @return didCap compounded interest rate was above the treshold and was capped.
    /// @return didOverflow compounded interest rate was limited to prevent overflow.
    function compoundInterestRate(
        Setup memory _setup, 
        int256 _t0,
        int256 _t1, 
        int256 _u,
        int256 _totalDeposits,
        int256 _totalBorrowAmount
    )
        external
        pure
        returns (int256 rcomp, int256 k, bool didCap, bool didOverflow);

    /// @notice Calculate current interest rate, refer model whitepaper for more details.
    /// @param _setup DynamicKinkModelV1 config struct with model state.
    /// @param _t0 timestamp of the last interest rate update.
    /// @param _t1 timestamp of the current interest rate calculations (current time).
    /// @param _u utilization ratio of silo and asset at _t1.
    /// @param _totalDeposits total deposits at _t1.
    /// @param _totalBorrowAmount total borrow amount at _t1.
    /// @return rcur current interest in decimal points.
    /// @return didCap current interest rate was above the treshold and was capped.
    /// @return didOverflow current interest rate was limited to prevent overflow.
    function currentInterestRate(
        Setup memory _setup, 
        int256 _t0, 
        int256 _t1, 
        int256 _u,
        int256 _totalDeposits,
        int256 _totalBorrowAmount
    )
        external
        pure
        returns (int256 rcur, bool didCap, bool didOverflow);
}
