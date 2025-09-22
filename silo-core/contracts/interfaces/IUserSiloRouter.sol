// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface IUserSiloRouter {
    error OnlySiloRouter();
    error Paused();

    /// @param _data The data to be executed.
    /// @param _msgSender The address of the message sender.
    function multicall(bytes[] calldata _data, address _msgSender) external payable returns (bytes[] memory results);
}
