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
    /* solhint-enable */

    error AddressZero();
    error DeployConfigFirst();
    error AlreadyConnected();    
}
