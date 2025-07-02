// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";

import {ILeverageUsingSiloFlashloan} from "../interfaces/ILeverageUsingSiloFlashloan.sol";

import {GeneralSwapModule, IGeneralSwapModule} from "./modules/GeneralSwapModule.sol";
import {LeverageUsingSiloFlashloan} from "./LeverageUsingSiloFlashloan.sol";

/// @notice This contract allow to create and close leverage position using flasnloan and swap.
contract LeverageUsingSiloFlashloanWithGeneralSwap is
    ILeverageUsingSiloFlashloan,
    LeverageUsingSiloFlashloan
{
    using SafeERC20 for IERC20;

    string public constant DESCRIPTION = "Leverage with silo flashloan and 0x (or compatible) swap";

    /// @notice The swap module is designed to execute external calls and is under the caller's full control.
    /// It can call any contract using any method. NEVER approve any tokens for it!
    IGeneralSwapModule public immutable SWAP_MODULE;

    constructor (address _initialOwner, address _native) Ownable(_initialOwner) LeverageUsingSiloFlashloan(_native) {
        SWAP_MODULE = new GeneralSwapModule();
    }

    function _fillQuote(bytes memory _swapArgs, uint256 _maxApprovalAmount)
        internal
        virtual
        override
        returns (uint256 amountOut)
    {
        IGeneralSwapModule.SwapArgs memory swapArgs = abi.decode(_swapArgs, (IGeneralSwapModule.SwapArgs));

        uint256 sellTokenBalance = IERC20(swapArgs.sellToken).balanceOf(address(this));
        IERC20(swapArgs.sellToken).safeTransfer(address(SWAP_MODULE), sellTokenBalance);

        amountOut = SWAP_MODULE.fillQuote(swapArgs, _maxApprovalAmount);
    }
}
