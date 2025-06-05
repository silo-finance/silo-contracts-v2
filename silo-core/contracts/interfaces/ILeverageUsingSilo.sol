// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ISilo, IERC3156FlashLender} from "./ISilo.sol";

/// @title LeverageUsingSilo Interface
/// @notice Interface for a contract that enables leveraged deposits using flash loans from silo
/// and token swaps with 0x os compatible interface
interface ILeverageUsingSilo {
    enum LeverageAction {
        Undefined,
        Open,
        Close
    }

    /// @notice Parameters for a flash loan
    /// @param flashloanTarget The address of the contract providing the flash loan
    /// @param amount The amount of tokens to borrow
    struct FlashArgs {
        address flashloanTarget;
        uint256 amount;
    }

    /// @notice Parameters for deposit after leverage
    /// @param silo Target Silo for depositing
    /// @param amount Raw deposit amount (excluding flashloan)
    /// @param collateralType The type of collateral to use
    struct DepositArgs {
        ISilo silo;
        uint256 amount;
        ISilo.CollateralType collateralType;
    }

    /// @param siloWithCollateral address of silo with collateral, the other silo is expected to have debt
    /// @param collateralType The type of collateral to use
    struct CloseLeverageArgs {
        ISilo siloWithCollateral;
        ISilo.CollateralType collateralType;
    }

    /// @dev emit when leverage position is open
    /// Fees can be calculated based on event data:
    /// - leverage fee = borrowerDeposit + swapAmountOut - totalDeposit
    /// - flashloan fee = totalBorrow - flashloanAmount
    event OpenLeverage(
        address indexed borrower,
        uint256 borrowerDeposit,
        uint256 swapAmountOut,
        uint256 flashloanAmount,
        uint256 totalDeposit,
        uint256 totalBorrow
    );

    event CloseLeverage(
        address indexed borrower,
        uint256 flashloanRepay,
        uint256 swapAmountOut,
        uint256 depositWithdrawn
    );

    error FlashloanFailed();
    error InvalidFlashloanLender();
    error InvalidInitiator();
    error UnknownAction();
    error SwapDidNotCoverObligations();
    error InvalidSilo();
    error LeverageToLowToCoverFee();

    /// @notice Performs leverage operation using a flash loan and token swap
    /// @dev Reverts if the amount is so high that fee calculation fails
    /// @param _flashArgs Flash loan configuration
    /// @param _swapArgs Swap call data and settings, that will swap all flashloan amount into collateral
    /// @param _depositArgs Final deposit configuration into a Silo
    function openLeveragePosition(
        FlashArgs calldata _flashArgs,
        bytes calldata _swapArgs,
        DepositArgs calldata _depositArgs
    ) external;

    /// @param _flashArgs Flash loan configuration
    /// @param _swapArgs Swap call data and settings,
    /// that should swap enough collateral to repay flashloan in debt token
    /// @param _closeLeverageArgs configuration for closing position
    function closeLeveragePosition(
        FlashArgs calldata _flashArgs,
        bytes calldata _swapArgs,
        CloseLeverageArgs calldata _closeLeverageArgs
    ) external;
}
