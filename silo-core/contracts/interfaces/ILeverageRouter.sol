// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ILeverageUsingSiloFlashloan} from "./ILeverageUsingSiloFlashloan.sol";

/// @title ILeverageRouter
/// @notice Leverage router deploys for every user it's own leverage contract.
interface ILeverageRouter {
    /// @notice Emitted when a new leverage contract is created for a user
    event LeverageContractCreated(address indexed user, address indexed leverageContract);
    /// @notice Emitted when the leverage fee is updated
    /// @param leverageFee New leverage fee
    event LeverageFeeChanged(uint256 leverageFee);
    /// @notice Emitted when the revenue receiver address is changed
    /// @param receiver New receiver address
    event RevenueReceiverChanged(address indexed receiver);

    /// @dev Thrown when the leverage implementation is empty
    error EmptyLeverageImplementation();
    /// @dev Thrown when trying to set the same fee as the current one
    error FeeDidNotChanged();
    /// @dev Thrown when trying to set the same revenue receiver
    error ReceiverDidNotChanged();
    /// @dev Thrown when the receiver address is zero
    error ReceiverZero();
    /// @dev Thrown when the provided fee is invalid (>= 100%)
    error InvalidFee();


    /// @notice Performs leverage operation using a flash loan and token swap
    /// @dev Executes a call to the leverage contract.
    /// @param _flashArgs Flash loan configuration
    /// @param _swapArgs Swap call data and settings, that will swap all flashloan amount into collateral
    /// @param _depositArgs Final deposit configuration into a Silo
    function openLeveragePosition(
        ILeverageUsingSiloFlashloan.FlashArgs calldata _flashArgs,
        bytes calldata _swapArgs,
        ILeverageUsingSiloFlashloan.DepositArgs calldata _depositArgs
    ) external payable;

    /// @notice Performs leverage operation using a flash loan and token swap
    /// @dev Executes a call to the leverage contract.
    /// @param _flashArgs Flash loan configuration
    /// @param _swapArgs Swap call data and settings, that will swap all flashloan amount into collateral
    /// @param _depositArgs Final deposit configuration into a Silo
    /// @param _depositAllowance Permit for leverage contract to transfer collateral from borrower
    function openLeveragePositionPermit(
        ILeverageUsingSiloFlashloan.FlashArgs calldata _flashArgs,
        bytes calldata _swapArgs,
        ILeverageUsingSiloFlashloan.DepositArgs calldata _depositArgs,
        ILeverageUsingSiloFlashloan.Permit calldata _depositAllowance
    ) external;

    /// @dev Closes leverage position by swapping collateral to debt token.
    /// @dev Executes a call to the leverage contract.
    /// @param _swapArgs Swap call data and settings,
    /// that should swap enough collateral to repay flashloan in debt token
    /// @param _closeLeverageArgs configuration for closing position
    function closeLeveragePosition(
        bytes calldata _swapArgs,
        ILeverageUsingSiloFlashloan.CloseLeverageArgs calldata _closeLeverageArgs
    ) external;

    /// @dev Closes leverage position by swapping collateral to debt token.
    /// @dev Executes a call to the leverage contract.
    /// @param _swapArgs Swap call data and settings,
    /// that should swap enough collateral to repay flashloan in debt token
    /// @param _closeLeverageArgs configuration for closing position
    /// @param _withdrawAllowance Permit for leverage contract to withdraw all borrower collateral tokens
    function closeLeveragePositionPermit(
        bytes calldata _swapArgs,
        ILeverageUsingSiloFlashloan.CloseLeverageArgs calldata _closeLeverageArgs,
        ILeverageUsingSiloFlashloan.Permit calldata _withdrawAllowance
    ) external;

    /// @notice Set the address that receives collected revenue
    /// @param _receiver New address to receive fees
    function setRevenueReceiver(address _receiver) external;

    /// @notice Set the leverage fee
    /// @param _fee New leverage fee (must be < FEE_PRECISION)
    function setLeverageFee(uint256 _fee) external;

    /// @notice Unpause the leverage router
    function unpause() external;

    /// @notice Pause the leverage router
    function pause() external;

    /// @notice Returns the leverage fee
    /// @return fee The leverage fee
    function leverageFee() external view returns (uint256 fee);

    /// @notice Returns the revenue receiver
    /// @return receiver Address of the revenue receiver
    function revenueReceiver() external view returns (address receiver);

    /// @notice Returns the leverage contract for a given user
    /// @param _user The address of the user
    /// @return leverageContract
    function predictUserLeverageContract(address _user) external view returns (address leverageContract);

    /// @notice Returns the leverage implementation
    /// @return implementation The leverage implementation
    function LEVERAGE_IMPLEMENTATION() external view returns (address implementation);
}
