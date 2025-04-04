// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {ISilo} from "./ISilo.sol";
import {IWrappedNativeToken} from "./IWrappedNativeToken.sol";

interface ISiloRouterV2 {
    /// @param _data The data to be executed.
    function multicall(bytes[] calldata _data) external payable returns (bytes[] memory results);

    /// @notice Pause the router
    /// @dev Pausing the router will prevent any actions from being executed
    function pause() external;

    /// @notice Unpause the router
    function unpause() external;
}
