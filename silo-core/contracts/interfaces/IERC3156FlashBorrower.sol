// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface IERC3156FlashBorrower {
    /// @notice During the execution of the flashloan, Silo methods are not taking into consideration the fact,
    /// that some (or all) tokens were transferred as flashloan, therefore some methods can return invalid state
    /// eg. maxWithdraw can return amount that are not available to withdraw during flashlon.
    /// @dev Receive a flash loan.
    /// @param _initiator The initiator of the loan.
    /// @param _token The loan currency.
    /// @param _amount The amount of tokens lent.
    /// @param _fee The additional amount of tokens to repay.
    /// @param _data Arbitrary data structure, intended to contain user-defined parameters.
    /// @return The keccak256 hash of "ERC3156FlashBorrower.onFlashLoan"
    function onFlashLoan(address _initiator, address _token, uint256 _amount, uint256 _fee, bytes calldata _data)
        external
        returns (bytes32);
}
