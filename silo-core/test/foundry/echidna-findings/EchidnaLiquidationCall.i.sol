// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {EchidnaMiddleman} from "./EchidnaMiddleman.sol";

/*
    forge test -vv --ffi --mc EchidnaLiquidationCallTest
*/
contract EchidnaLiquidationCallTest is EchidnaMiddleman {
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

/*
cannotPreventInsolventUserFromBeingLiquidated(uint8,bool): failed!💥
  Call sequence, shrinking 25/500:
    EchidnaE2E.previewMint_DoesNotReturnLessThanMint(0,505701250604590645656963514028982080456108145830671282357774219109237)
    EchidnaE2E.mint(1,false,7719965595890521662560071)
    EchidnaE2E.maxBorrow_correctReturnValue(1)
    EchidnaE2E.maxWithdraw_correctMax(1)
    EchidnaE2E.maxWithdraw_correctMax(0)
    EchidnaE2E.cannotPreventInsolventUserFromBeingLiquidated(1,false) Time delay: 16 seconds Block delay: 11


    forge test -vv --ffi --mt test_echidna_scenario_cannotPreventInsolventUserFromBeingLiquidated_4

    this is failing in Echidna, but not for foundry
*/
    function test_echidna_scenario_cannotPreventInsolventUserFromBeingLiquidated_4() public {
        __previewMint_DoesNotReturnLessThanMint(0,505701250604590645656963514028982080456108145830671282357774219109237);
        __mint(1,false,7719965595890521662560071);
        __maxBorrow_correctReturnValue(1);
        __maxWithdraw_correctMax(1);
        __maxWithdraw_correctMax(0);

        __timeDelay(16);
        __cannotPreventInsolventUserFromBeingLiquidated(1,false); // Time delay: 16 seconds Block delay: 11
    }

/*
cannotPreventInsolventUserFromBeingLiquidated(uint8,bool): failed!💥
  Call sequence, shrinking 31/500:
    EchidnaE2E.previewMint_DoesNotReturnLessThanMint(0,235453338624375331692399204420018186514240492170733884179568266784186)
    EchidnaE2E.mint(1,false,8089643688031601350836230)
    EchidnaE2E.maxBorrow_correctReturnValue(1)
    EchidnaE2E.maxWithdraw_correctMax(1)
    EchidnaE2E.maxWithdraw_correctMax(0)
    EchidnaE2E.cannotPreventInsolventUserFromBeingLiquidated(1,false) Time delay: 16 seconds Block delay: 11

    forge test -vv --ffi --mt test_echidna_scenario_cannotPreventInsolventUserFromBeingLiquidated_5

    can not replicate echidna
*/
    function test_echidna_scenario_cannotPreventInsolventUserFromBeingLiquidated_5() public {
        __previewMint_DoesNotReturnLessThanMint(0,235453338624375331692399204420018186514240492170733884179568266784186);
        __mint(1,false,8089643688031601350836230);
        __maxBorrow_correctReturnValue(1);
        __maxWithdraw_correctMax(1);
        __maxWithdraw_correctMax(0);

        __timeDelay(16);
        __cannotPreventInsolventUserFromBeingLiquidated(1,false); // Time delay: 16 seconds Block delay: 11
    }
}
