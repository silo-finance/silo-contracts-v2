// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Ownable} from "openzeppelin5/access/Ownable2Step.sol";

import {ILeverageUsingSilo} from "../interfaces/ILeverageUsingSilo.sol";
import {LeverageUsingSilo} from "./LeverageUsingSilo.sol";

/*
    @notice This contract allow to create and close leverage position using flasnloan and swap.
    It supports Pendle swap.
*/
contract LeverageUsingSiloWithPendle is
    ILeverageUsingSilo,
    LeverageUsingSilo
{
    constructor (address _initialOwner) Ownable(_initialOwner) {
    }

    function _fillQuote(bytes memory _swapArgs, uint256 _approval)
        internal
        virtual
        override
        returns (uint256 amountOut)
    {
        // TODO execute pendle swap
    }
}
