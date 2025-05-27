// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";

import {RevertLib} from "../lib/RevertLib.sol";

import {ISilo} from "../interfaces/ISilo.sol";
import {ILeverageUsingSilo} from "../interfaces/ILeverageUsingSilo.sol";
import {IERC3156FlashBorrower} from "../interfaces/IERC3156FlashBorrower.sol";
import {IERC3156FlashLender} from "../interfaces/IERC3156FlashLender.sol";

import {RevenueModule} from "./modules/RevenueModule.sol";
import {LeverageReentrancy} from "./modules/LeverageReentrancy.sol";
import {ZeroExSwapModule} from "./modules/ZeroExSwapModule.sol";
import {LeverageUsingSilo} from "./LeverageUsingSilo.sol";

/*
    @notice This contract allow to create and close leverage position using flasnloan and swap.
    It supports 0x interface for swap.
*/
contract LeverageUsingSiloWithZeroEx is
    ILeverageUsingSilo,
    LeverageUsingSilo,
    ZeroExSwapModule
{
    constructor (address _initialOwner) Ownable(_initialOwner) {
    }

    function _fillQuote(bytes memory _swapArgs, uint256 _approval)
        internal
        virtual
        override(LeverageUsingSilo, ZeroExSwapModule)
        returns (uint256 amountOut)
    {
        amountOut = ZeroExSwapModule._fillQuote(_swapArgs, _approval);
    }
}
