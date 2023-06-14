// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import "uniswap/v2-core/contracts/interfaces/IERC20.sol";

/// @dev source: uniswap
/// This is copy of original code except that:
/// - custom errors were added
/// - removed unused functions to reduce deployments size
/// - there was conflict with openzepellin IERC20
contract SafeTransferETH {
    error STE();

    /// @notice Transfers ETH to the recipient address
    /// @dev Fails with `STE`
    /// @param to The destination of the transfer
    /// @param value The value to be transferred
    function _safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        if (!success) revert STE();
    }
}
