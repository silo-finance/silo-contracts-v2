// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Address} from "openzeppelin5/utils/Address.sol";

/// @title SiloRouter
/// @notice Silo Router is a utility contract that aims to improve UX. It can batch any number or combination
/// of actions (Deposit, Withdraw, Borrow, Repay) and execute them in a single transaction.
/// @dev SiloRouter requires only first action asset to be approved
/// @custom:security-contact security@silo.finance
contract SiloRouter {
    error EthTransferFailed();
    error InvalidInputLength();

    /// @dev needed for unwrapping WETH
    receive() external payable {
        // `execute` method calls `IWrappedNativeToken.withdraw()`
        // and we need to receive the withdrawn ETH unconditionally
    }

    /// @notice Multicall is a utility function
    /// that allows you to batch multiple calls to different contracts in a single transaction.
    /// @param targets The addresses of the contracts to call.
    /// @param data The data to be passed to each contract.
    /// @param values The values to be passed to each contract.
    /// @return results The results of each call.
    function multicall(
        address[] calldata targets,
        bytes[] calldata data,
        uint256[] calldata values
    ) external payable returns (bytes[] memory results) {
        require(targets.length == data.length && targets.length == values.length, InvalidInputLength());

        results = new bytes[](targets.length);

        for (uint256 i = 0; i < targets.length; i++) {
            results[i] = Address.functionCallWithValue(targets[i], data[i], values[i]);
        }

        // if there is leftover ETH, send it back to the caller
        if (msg.value != 0 && address(this).balance != 0) {
            // solhint-disable-next-line avoid-low-level-calls
            (bool success,) = msg.sender.call{value: address(this).balance}("");
            require(success, EthTransferFailed());
        }
    }
}
