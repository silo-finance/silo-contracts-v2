// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

interface IAmmStateModel {
    /// TODO not sure, if this exponential model is really useful, need to verify in QA
    /// @dev share = m * 2^e;
    struct Share {
        uint112 m;
        uint112 e;
    }

    // this is to avoid stack too deep, it might be less than another function call TODO verify it
    struct Deltas {
        uint256 dA;
        uint256 dC;
        uint256 dS;
        uint256 dV;
    }

    struct TotalState {
        /// @dev the total amount of collateral historically provided (denominated in collateral tokens) (A)
        uint256 collateralAmount;

        /// @dev the total liquidation-time value of collateral (V)
        uint256 liquidationTimeValue;

        /// @dev the total number of shares (S)
        uint256 shares;

        /// @dev the total amount of remaining (not yet swapped) collateral in the pool (C)
        uint256 availableCollateral;

        /// @dev the total amount of debt token in the pool (D)
        uint256 debtAmount;

        /// @dev an auxiliary variable, explained in the internal documentation (R)
        uint256 R; // solhint-disable-line var-name-mixedcase
    }

    struct UserPosition {
        /// @dev amount of collateral historically provided by the user (denominated in collateral tokens) (Ai)
        uint256 collateralAmount;

        /// @dev liquidation-time value of collateral provided by the user (Vi)
        uint256 liquidationTimeValue;

        /// @dev number of shares held by the user (Si)
        uint256 shares;
    }

    error USER_NOT_CLEANED_UP();
    error NOT_ENOUGH_AVAILABLE_COLLATERAL();
    error NO_COLLATERAL();
}
