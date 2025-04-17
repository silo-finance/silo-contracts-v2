// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

interface ICheck {
    /// @dev check name to log when check passes or fails. Must describe the `execute()` function For example,
    /// "Oracle price is equal to an external source".
    function checkName() external returns (string memory name);

    /// @dev message to log when check passes. Must include all important details. For example, can return
    /// "Price from the oracle (12.02$) is equal to the external source `12$` with 0.1% precision error allowed."
    /// Function may revert if called before .execute().
    function successMessage() external returns (string memory message);

    /// @dev message to log when check fails. Must include all important details for debugging. For example, can return
    /// "Price from the oracle (15$) is NOT equal to the external source `12$` with 0.1 precision error."
    /// Function may revert if called before .execute().
    function errorMessage() external returns (string memory message);

    /// @dev execute Silo check
    /// @return result true if everything is correct, false if check failed.
    function execute() external returns (bool result);
}
