// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {RevertLib} from "../../lib/RevertLib.sol";
import {IZeroExSwapModule} from "../../interfaces/IZeroExSwapModule.sol";

/// @title 0x and ODOS Compatible ERC20 Swap Module
/// @notice Enables ERC20 token swaps via an external exchange proxy (e.g., 0x, ODOS)
/// @dev Based on the 0x demo contract: https://github.com/0xProject/0x-api-starter-guide-code/blob/master/contracts/SimpleTokenSwap.sol
contract ZeroExSwapModule is IZeroExSwapModule {
    using SafeERC20 for IERC20;

    /// @notice Executes a token swap using a prebuilt swap quote
    /// @dev The contract must hold the sell token balance before calling. Requires ETH attached equal to the swap quote value.
    /// @param _swapArgs Struct containing all parameters for executing a swap
    /// @param _approval Amount of sell token to approve before the swap
    /// @return amountOut Amount of buy token received after the swap
    function _fillQuote(SwapArgs memory _swapArgs, uint256 _approval) internal virtual returns (uint256 amountOut) {
        if (_swapArgs.exchangeProxy == address(0)) revert ExchangeAddressZero();

        // Approve token for spending by the exchange
        IERC20(_swapArgs.sellToken).forceApprove(_swapArgs.allowanceTarget, _approval); // TODO max?

        // solhint-disable-next-line avoid-low-level-calls
        // Perform low-level call to external exchange proxy
        (bool success, bytes memory data) = _swapArgs.exchangeProxy.call(_swapArgs.swapCallData);
        if (!success) RevertLib.revertBytes(data, SwapCallFailed.selector);

        // Reset approval to 1 to avoid lingering allowances
        IERC20(_swapArgs.sellToken).forceApprove(_swapArgs.allowanceTarget, 1);

        // TODO will this work if anyone delegate token?
        amountOut = IERC20(_swapArgs.buyToken).balanceOf(address(this));
    }
}
