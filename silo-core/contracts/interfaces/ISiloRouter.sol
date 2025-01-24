// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {ISilo} from "./ISilo.sol";
import {IWrappedNativeToken} from "./IWrappedNativeToken.sol";

interface ISiloRouter {
    /// @param _data The data to be executed.
    function multicall(bytes[] calldata _data) external payable returns (bytes[] memory results);

    /// @notice Wrap native token to wrapped native token
    /// @param _native The address of the native token
    /// @param _amount The amount of native token to wrap
    function wrap(IWrappedNativeToken _native, uint256 _amount) external payable;

    /// @notice Unwrap wrapped native token to native token
    /// @param _native The address of the native token
    /// @param _amount The amount of wrapped native token to unwrap
    function unwrap(IWrappedNativeToken _native, uint256 _amount) external payable;

    /// @notice Pause the router
    /// @dev Pausing the router will prevent any actions from being executed
    function pause() external;

    /// @notice Unpause the router
    function unpause() external;

    /// @notice Transfer native token from the router to an address
    /// @param _to The address to transfer the native token to
    /// @param _amount The amount of native token to transfer
    function transferNative(address _to, uint256 _amount) external payable;

    /// @notice Transfer tokens
    /// @param _token The address of the token
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to transfer
    function transfer(IERC20 _token, address _to, uint256 _amount) external payable;

    /// @notice Transfer tokens from one address to another
    /// @param _token The address of the token
    /// @param _from The address of the sender
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to transfer
    function transferFrom(IERC20 _token, address _from, address _to, uint256 _amount) external payable;

    /// @notice Approve tokens for a specific spender
    /// @param _token The address of the token
    /// @param _spender The address of the spender
    /// @param _amount The amount of tokens to approve
    function approve(IERC20 _token, address _spender, uint256 _amount) external payable;

    /// @notice Deposit tokens into a silo
    /// @param _silo The address of the silo
    /// @param _amount The amount of tokens to deposit
    function deposit(ISilo _silo, uint256 _amount) external payable;
}
