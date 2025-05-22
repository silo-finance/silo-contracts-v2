// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ISilo, IERC3156FlashLender} from "./ISilo.sol";
import {IZeroExSwapModule} from "./IZeroExSwapModule.sol";

/// @title ISiloLeverage Interface
/// @notice Interface for a contract that enables leveraged deposits using flash loans and token swaps
interface ISiloLeverage {
    /// @notice Parameters for a flash loan
    /// @param flashDebtLender The address of the lender providing the flash loan
    /// @param token The token to borrow
    /// @param amount The amount of tokens to borrow
    struct FlashArgs {
        address flashDebtLender;
        address token;
        uint256 amount;
    }

    /// @notice Parameters for deposit after leverage
    /// @param silo Target Silo for depositing
    /// @param amount Raw deposit amount (excluding flashloan)
    /// @param collateralType The type of collateral to use
    /// @param receiver Address to receive the leveraged position
    struct DepositArgs {
        ISilo silo;
        uint256 amount;
        ISilo.CollateralType collateralType;
        address receiver;
    }

    /// @param borrower address of owner of leverage position
    /// @param siloWithDebt address of silo with debt
    /// @param borrowerDebtShares total borrower debt shares to repay
    /// @param siloWithCollateral address of silo with collateral
    /// @param collateralType The type of collateral to use
    /// @param sharesToWithdraw collateral shares to withdraw, it is expected to be total debt shares because
    /// swap is based on total user collateral
    struct CloseLeverageArgs {
        address borrower;
        ISilo siloWithDebt;
        uint256 borrowerDebtShares;
        ISilo siloWithCollateral;
        ISilo.CollateralType collateralType;
        uint256 collateralShares;
    }

    /// @notice Thrown when the flash loan fails to execute
    error FlashloanFailed();

    /// @notice Thrown if the provided flash loan lender is invalid or unsupported
    error InvalidFlashloanLender();
    error InvalidInitiator();
    error UnknownAction();
    error SwapDidNotCoverObligations();

    /// @notice Performs leverage operation using a flash loan and token swap
    /// @dev Reverts if the amount is so high that fee calculation fails
    /// @param _flashArgs Flash loan configuration
    /// @param _swapArgs Swap call data and settings
    /// @param _depositArgs Final deposit configuration into a Silo
    /// @param _borrowSilo The Silo to borrow from. In general, it should be the "other" silo from the same market.
    /// @return multiplier Leverage multiplier achieved by the operation
    function leverage(
        FlashArgs calldata _flashArgs,
        IZeroExSwapModule.SwapArgs calldata _swapArgs,
        DepositArgs calldata _depositArgs,
        ISilo _borrowSilo
    ) external returns (uint256 multiplier);

//
//    function closeLeverage(
//        ISilo _silo,
//        ISilo.CollateralType _collateralType,
//        IERC3156FlashLender _flashloanLender
//    ) external view virtual override returns (ISilo);
}
