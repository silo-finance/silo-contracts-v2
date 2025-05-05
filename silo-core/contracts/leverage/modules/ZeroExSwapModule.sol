// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {RevertLib} from "../../lib/RevertLib.sol";

/// @dev Based on demo contract that swaps its ERC20 balance for another ERC20.
/// demo source: https://github.com/0xProject/0x-api-starter-guide-code/blob/master/contracts/SimpleTokenSwap.sol
/// compatible with 0x and ODOS
contract ZeroExSwapModule {
    using SafeERC20 for IERC20;

    /// @notice data for exchange proxy to perform the swap
    /// @param sellToken The `sellTokenAddress` field from the API response.
    /// @param buyToken The `buyTokenAddress` field from the API response.
    /// @param allowanceTarget The `allowanceTarget` (spender) field from the API response.
    /// @param swapCallData The `data` field from the API response.
    struct SwapArgs {
        address exchangeProxy;
        address sellToken;
        address buyToken;
        address allowanceTarget;
        bytes swapCallData;
    }

    error ExchangeAddressZero();
    error SwapCallFailed();

    /// @dev Swaps ERC20->ERC20 tokens held by this contract using a API quote.
    /// Must attach ETH equal to the `value` field from the API response.
    /// @param _exchangeProxy ExchangeProxy address.
    /// See https://docs.0x.org/developer-resources/contract-addresses
    /// The `to` field from the API response
    /// @param _sellToken The `sellTokenAddress` field from the API response.
    /// @param _spender The `allowanceTarget` field from the API response.
    /// @param _swapCallData The `data` field from the API response.
    function _fillQuote(SwapArgs calldata _swapArgs, uint256 _approval) internal virtual returns (uint256 amountOut) {
        if (_swapArgs.exchangeProxy == address(0)) revert ExchangeAddressZero();

        uint256 balanceBefore = IERC20(_swapArgs.buyToken).balanceOf(address(this));

        IERC20(_swapArgs.sellToken).forceApprove(_swapArgs.allowanceTarget, _approval);

        // Call the encoded swap function call on the contract at `swapTarget`
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory data) = _swapArgs.exchangeProxy.call(_swapArgs.swapCallData);
        if (!success) RevertLib.revertBytes(data, SwapCallFailed.selector);

        IERC20(_swapArgs.sellToken).forceApprove(_swapArgs.allowanceTarget, 1);

        uint256 balanceAfter = IERC20(_swapArgs.buyToken).balanceOf(address(this));

        amountOut = balanceAfter - balanceBefore;
    }
}
