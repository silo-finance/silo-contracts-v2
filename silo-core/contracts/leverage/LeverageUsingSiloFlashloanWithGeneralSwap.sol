// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Ownable} from "openzeppelin5/access/Ownable2Step.sol";

import {ILeverageUsingSiloFlashloan} from "../interfaces/ILeverageUsingSiloFlashloan.sol";

import {GeneralSwapModule} from "./modules/GeneralSwapModule.sol";
import {LeverageUsingSiloFlashloan} from "./LeverageUsingSiloFlashloan.sol";

/*
    @notice This contract allow to create and close leverage position using flasnloan and swap.
*/
contract LeverageUsingSiloFlashloanWithGeneralSwap is
    ILeverageUsingSiloFlashloan,
    LeverageUsingSiloFlashloan,
    GeneralSwapModule
{
    string public constant DESCRIPTION = "Leverage with silo flashloan and 0x (or compatible) swap";

    constructor (address _initialOwner) Ownable(_initialOwner) {
    }

    function _fillQuote(bytes memory _swapArgs, uint256 _approval)
        internal
        virtual
        override(LeverageUsingSiloFlashloan, GeneralSwapModule)
        returns (uint256 amountOut)
    {
        amountOut = GeneralSwapModule._fillQuote(_swapArgs, _approval);
    }
}
