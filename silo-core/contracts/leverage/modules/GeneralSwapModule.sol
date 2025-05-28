// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {RevertLib} from "../../lib/RevertLib.sol";
import {IGeneralSwapModule} from "../../interfaces/IGeneralSwapModule.sol";

/// @title ERC20 General use Swap Module
/// @notice Enables ERC20 token swaps via an external exchange (e.g., 0x, ODOS, Pendle)
/// @dev Based on the 0x demo contract:
/// https://github.com/0xProject/0x-api-starter-guide-code/blob/master/contracts/SimpleTokenSwap.sol
abstract contract GeneralSwapModule is IGeneralSwapModule {
    using SafeERC20 for IERC20;

    /// @notice Executes a token swap using a prebuilt swap quote
    /// @dev The contract must hold the sell token balance before calling.
    /// @param _swapArgs SwapArgs struct as bytes containing containing all parameters for executing a swap
    /// @param _approval Amount of sell token to approve before the swap
    /// @return amountOut Amount of buy token received after the swap including any previous balance that contract has
    function _fillQuote(bytes memory _swapArgs, uint256 _approval) internal virtual returns (uint256 amountOut) {
        SwapArgs memory swapArgs = abi.decode(_swapArgs, (SwapArgs));

        if (swapArgs.exchangeProxy == address(0)) revert ExchangeAddressZero();

        // Approve token for spending by the exchange
        IERC20(swapArgs.sellToken).forceApprove(swapArgs.allowanceTarget, _approval); // TODO max?

        // Perform low-level call to external exchange proxy
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory data) = swapArgs.exchangeProxy.call(swapArgs.swapCallData);
        if (!success) RevertLib.revertBytes(data, SwapCallFailed.selector);

        // Reset approval to 1 to avoid lingering allowances
        IERC20(swapArgs.sellToken).forceApprove(swapArgs.allowanceTarget, 1);

        amountOut = IERC20(swapArgs.buyToken).balanceOf(address(this));
        if (amountOut == 0) revert ZeroAmountOut();
    }
}
