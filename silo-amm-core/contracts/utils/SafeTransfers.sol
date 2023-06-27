// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";

/// @dev source: uniswap
/// This is copy of original code except that:
/// - custom errors were added
/// - removed unused functions to reduce deployments size
/// - there was conflict with openzepellin IERC20
contract SafeTransfers {
    error ST();
    error STF();

    /// @notice Transfers tokens from msg.sender to a recipient
    /// @dev Errors with ST if transfer fails
    /// @param token The contract address of the token which will be transferred
    /// @param to The recipient of the transfer
    /// @param value The value of the transfer
    function _safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));

        if (!success) revert ST();
        if (data.length != 0 && !abi.decode(data, (bool))) revert ST();
    }

    /// @notice Transfers tokens from the targeted address to the given destination
    /// @notice Errors with 'STF' if transfer fails
    /// @param token The contract address of the token to be transferred
    /// @param from The originating address from which the tokens will be transferred
    /// @param to The destination address of the transfer
    /// @param value The amount to be transferred
    function _safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        (
            bool success,
            bytes memory data
            // solhint-disable-next-line avoid-low-level-calls
        ) = token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value));

        if (!success) revert STF();
        if (data.length != 0 && !abi.decode(data, (bool))) revert STF();
    }
}
