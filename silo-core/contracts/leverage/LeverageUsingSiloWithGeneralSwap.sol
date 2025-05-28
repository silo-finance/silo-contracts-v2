// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Ownable} from "openzeppelin5/access/Ownable2Step.sol";

import {ILeverageUsingSilo} from "../interfaces/ILeverageUsingSilo.sol";

import {GeneralSwapModule} from "./modules/GeneralSwapModule.sol";
import {LeverageUsingSilo} from "./LeverageUsingSilo.sol";

/*
    @notice This contract allow to create and close leverage position using flasnloan and swap.
*/
contract LeverageUsingSiloWithGeneralSwap is
    ILeverageUsingSilo,
    LeverageUsingSilo,
    GeneralSwapModule
{
    string public constant VERSION = "Leverage with silo flashloan and 0x (or compatible) swap";

    constructor (address _initialOwner) Ownable(_initialOwner) {
    }

    function _fillQuote(bytes memory _swapArgs, uint256 _approval)
        internal
        virtual
        override(LeverageUsingSilo, GeneralSwapModule)
        returns (uint256 amountOut)
    {
        amountOut = GeneralSwapModule._fillQuote(_swapArgs, _approval);
    }
}
