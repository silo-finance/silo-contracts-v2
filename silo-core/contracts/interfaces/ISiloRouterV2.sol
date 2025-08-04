// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {ISilo} from "./ISilo.sol";
import {IWrappedNativeToken} from "./IWrappedNativeToken.sol";

interface ISiloRouterV2 {
    event SiloRouterContractCreated(address indexed user, address siloRouter);

    /// @param _data The data to be executed.
    function multicall(bytes[] calldata _data) external payable returns (bytes[] memory results);

    /// @notice Pause the router
    /// @dev Pausing the router will prevent any actions from being executed
    function pause() external;

    /// @notice Unpause the router
    function unpause() external;

    /// @notice Get the initiator of the multicall
    /// @return msgSender
    function msgSender() external view returns (address);

    /// @notice Predict the address of the silo router contract for a user
    /// @param _user The user to predict the address for
    /// @return siloRouter The address of the silo router contract
    function predictUserSiloRouterContract(address _user) external view returns (address siloRouter);
}
