// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Strings} from "openzeppelin5/utils/Strings.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {EchidnaMiddleman} from "./EchidnaMiddleman.sol";

/*
    forge test -vv --ffi --mc EchidnaLiquidationCallTest
*/
contract EchidnaMaxLiquidationTest is EchidnaMiddleman {
    /*
maxLiquidation_correctReturnValue(uint8): failed!💥
  Call sequence, shrinking 150/500:
    __depositNeverMintsZeroShares(0,false,8340246401324457448803304)
    __depositNeverMintsZeroShares(29,true,13751433678069877022113795593016450257645111971714146450203208546834228244547)
    __maxBorrow_correctReturnValue(0)
    __maxRedeem_correctMax(5)
    __accrueInterest(false) Time delay: 345688 seconds Block delay: 10073
    __maxLiquidation_correctReturnValue(0)


    forge test -vv --ffi --mt test_echidna_maxLiquidation_1

    this is failing in Echidna, but not for foundry
    */
    function test_echidna_maxLiquidation_1() public {
        __depositNeverMintsZeroShares(0,false,8340246401324457448803304);
        __depositNeverMintsZeroShares(29,true,13751433678069877022113795593016450257645111971714146450203208546834228244547);
        __maxBorrow_correctReturnValue(0);
        __maxRedeem_correctMax(5);
        __timeDelay(345688);
        __accrueInterest(false); // Time delay: 345688 seconds Block delay: 10073
        __maxLiquidation_correctReturnValue(0);
    }
}
