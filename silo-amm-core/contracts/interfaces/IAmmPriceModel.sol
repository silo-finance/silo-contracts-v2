// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

interface IAmmPriceModel {
    /// @dev we using int type for variables only because, we need to support negative values in calculations
    /// this struct is only for getter, in contract we work with constants
    /// please refer to constants description of particular variables
    struct AmmPriceConfig {
        uint64 kMin;
        uint64 kMax;
        uint64 deltaK;
        uint64 vFast;
        uint32 tSlow;
        uint64 q;
    }

    struct AmmPriceState {
        /// @dev positive number, scope: [0, 1.0], where 1.0 is treated as 1e18
        uint64 k;

        /// @dev last time of swap or adding liquidity (tCur)
        uint64 lastActionTimestamp;

        /// @dev the indicator that the previous action was adding liquidity. (AL)
        bool liquidityAdded;

        /// @dev period of time T1 for which the price should reach the minimum reasonable value
        bool swap;

        /// @dev flag that will be set on first ever liquidity added
        bool init;
    }

    error INVALID_K_MIN();
    error INVALID_K_MAX();
    error INVALID_T_SLOW();
    error INVALID_Q();
    error INVALID_V_FAST();
    error INVALID_DELTA_K();

    error VALUE_OUT_OF_SCOPE();
    error CAST_OVERFLOW();
    error LIQUIDATION_THRESHOLD_OVERFLOW();
}
