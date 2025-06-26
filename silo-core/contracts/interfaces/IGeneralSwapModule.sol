// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IGeneralSwapModule {
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
    error Swap();
    error ZeroAmountOut();

    function fillQuote(SwapArgs memory _swapArgs, uint256 _maxApprovalAmount) external returns (uint256 amountOut);
}
