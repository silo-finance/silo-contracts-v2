// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {IERC3156FlashBorrower} from "./IERC3156FlashBorrower.sol";

/// @notice https://eips.ethereum.org/EIPS/eip-3156
interface IERC3156FlashLender {
    /// @notice Protected deposits are not available for a flash loan.
    /// During the execution of the flashloan, Silo methods are not taking into consideration the fact,
    /// that some (or all) tokens were transferred as flashloan, therefore some methods can return invalid state
    /// eg. maxWithdraw can return amount that are not available to withdraw during flashlon.
    /// @dev Initiate a flash loan.
    /// @param _receiver The receiver of the tokens in the loan, and the receiver of the callback.
    /// @param _token The loan currency.
    /// @param _amount The amount of tokens lent.
    /// @param _data Arbitrary data structure, intended to contain user-defined parameters.
    function flashLoan(IERC3156FlashBorrower _receiver, address _token, uint256 _amount, bytes calldata _data)
        external
        returns (bool);

    /// @dev The amount of currency available to be lent.
    /// @param _token The loan currency.
    /// @return The amount of `token` that can be borrowed.
    function maxFlashLoan(address _token) external view returns (uint256);

    /// @dev The fee to be charged for a given loan.
    /// @param _token The loan currency.
    /// @param _amount The amount of tokens lent.
    /// @return The amount of `token` to be charged for the loan, on top of the returned principal.
    function flashFee(address _token, uint256 _amount) external view returns (uint256);
}
