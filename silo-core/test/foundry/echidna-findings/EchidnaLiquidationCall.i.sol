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
    function test_echidna_scenario_cannotPreventInsolventUserFromBeingLiquidated_1() public {
        __deposit(18,true,115792089237316195423570985008687907853269984665640564039416137476239236817613);
        __mint(2,false,63974401570004720028008811964);
        __maxBorrowShares_correctReturnValue(2);
        __maxWithdraw_correctMax(2);
        __maxWithdraw_correctMax(0);
        __timeDelay(1);
        __cannotPreventInsolventUserFromBeingLiquidated(2,false); // Time delay: 1 seconds Block delay: 19
    }

    /*
cannotPreventInsolventUserFromBeingLiquidated(uint8,bool): failed!💥
  Call sequence, shrinking 204/500:
    previewMint_DoesNotReturnLessThanMint(0,998580745521568906123431045994388972844614585967071034011630422)
    mint(1,false,2565959170339923665154)
    maxBorrow_correctReturnValue(1)
    maxWithdraw_correctMax(1)
    maxWithdraw_correctMax(0)
    cannotPreventInsolventUserFromBeingLiquidated(1,false) Time delay: 66 seconds Block delay: 27

    forge test -vv --ffi --mt test_echidna_scenario_cannotPreventInsolventUserFromBeingLiquidated_2

    this is failing in Echidna, but not for foundry
    */
    function test_echidna_scenario_cannotPreventInsolventUserFromBeingLiquidated_2() public {
        __previewMint_DoesNotReturnLessThanMint(0,998580745521568906123431045994388972844614585967071034011630422);
        __mint(1,false,2565959170339923665154);
        __maxBorrow_correctReturnValue(1);
        __maxWithdraw_correctMax(1);
        __maxWithdraw_correctMax(0);

        __timeDelay(66);
        __cannotPreventInsolventUserFromBeingLiquidated(1,false); // Time delay: 66 seconds Block delay: 27
    }


/*
cannotPreventInsolventUserFromBeingLiquidated(uint8,bool): failed!💥  
  Call sequence, shrinking 93/500:
    __previewMint_DoesNotReturnLessThanMint(0,415554698522287941383523311076411946429434413653696897585260622204445)
    __mint(1,false,1942172570619784772958589)
    __maxBorrow_correctReturnValue(1)
    __maxWithdraw_correctMax(1)
    __maxWithdraw_correctMax(0)
    __cannotPreventInsolventUserFromBeingLiquidated(1,false) Time delay: 46 seconds Block delay: 140
    
    forge test -vv --ffi --mt test_echidna_scenario_cannotPreventInsolventUserFromBeingLiquidated_3

    this is failing in Echidna, but not for foundry
    */
    function test_echidna_scenario_cannotPreventInsolventUserFromBeingLiquidated_3() public {
        __previewMint_DoesNotReturnLessThanMint(0,415554698522287941383523311076411946429434413653696897585260622204445);
        __mint(1,false,1942172570619784772958589);
        __maxBorrow_correctReturnValue(1);
        __maxWithdraw_correctMax(1);
        __maxWithdraw_correctMax(0);

        __timeDelay(46);
        __cannotPreventInsolventUserFromBeingLiquidated(1,false); // Time delay: 46 seconds Block delay: 140
    }
}