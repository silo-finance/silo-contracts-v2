// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface IComplianceResolver {
    /// @notice Check if the address is compliant with the action.
    /// @param _siloConfig The address of the silo config.
    /// @param _silo The address of the silo.
    /// @param _action The silo hook action to check.
    /// list of the possible actions:
    /// - deposit
    /// - borrow
    /// - borrow same asset
    /// - repay
    /// - withdraw
    /// - flash loan
    /// - transition collateral
    /// - switch collateral
    /// - liquidation
    /// - share collateral token transfer
    /// - share protected collateral token transfer
    /// - share debt token transfer
    /// @param _actionData The same data that we receive in the hook from the silo.
    /// @return isCompliant True if the address is compliant with the action.
    function isCompliant(
        address _siloConfig,
        address _silo,
        uint256 _action,
        bytes calldata _actionData
    ) external view returns (bool);
}
