// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Strings} from "openzeppelin5/utils/Strings.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {EchidnaMiddleman} from "./EchidnaMiddleman.sol";

/*
    forge test -vv --ffi --mc EchidnaLiquidationCallTest
*/
contract EchidnaLiquidationCallTest is EchidnaMiddleman {
    /*
cannotPreventInsolventUserFromBeingLiquidated(uint8,bool): failed!💥
  Call sequence, shrinking 67/500:
    deposit(18,true,115792089237316195423570985008687907853269984665640564039416137476239236817613)
    mint(2,false,63974401570004720028008811964)
    maxBorrowShares_correctReturnValue(2)
    maxWithdraw_correctMax(2)
    maxWithdraw_correctMax(0)
    cannotPreventInsolventUserFromBeingLiquidated(2,false) Time delay: 1 seconds Block delay: 19


    forge test -vv --ffi --mt test_echidna_scenario_liquidationCall_1

    this is failing in Echidna, but not for foundry
    */
    function test_echidna_scenario_liquidationCall_1() public {
        __deposit(18,true,115792089237316195423570985008687907853269984665640564039416137476239236817613);
        __mint(2,false,63974401570004720028008811964);
        __maxBorrowShares_correctReturnValue(2);
        __maxWithdraw_correctMax(2);
        __maxWithdraw_correctMax(0);
        __timeDelay(1);
        __cannotPreventInsolventUserFromBeingLiquidated(2,false); // Time delay: 1 seconds Block delay: 19
    }
}
