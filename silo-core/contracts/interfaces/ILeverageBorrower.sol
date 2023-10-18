// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface ILeverageBorrower {
    /// @dev Receive a leveraged loan with a single swap loop
    /// @param _initiator The initiator of the leveraged loan
    /// @param _borrower The borrower of the leveraged loan
    /// @param _asset The loan currency
    /// @param _assets The amount of tokens borrowed
    /// @param _data Arbitrary data structure, intended to contain user-defined parameters
    /// @return The keccak256 hash of "ILeverageBorrower.onLeverage"
    function onLeverage(address _initiator, address _borrower, address _asset, uint256 _assets, bytes calldata _data)
        external
        returns (bytes32);
}
