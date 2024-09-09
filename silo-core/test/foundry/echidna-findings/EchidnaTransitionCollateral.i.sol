// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Strings} from "openzeppelin5/utils/Strings.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {EchidnaMiddleman} from "./EchidnaMiddleman.sol";

/*
    forge test -vv --ffi --mc EchidnaMaxWithdrawTest
*/
contract EchidnaTransitionCollateralTest is EchidnaMiddleman {
    /*
transitionCollateral_doesNotResultInMoreShares(uint8,bool,uint256,uint8): failed!💥
  Call sequence, shrinking 163/500:
    previewDeposit_doesNotReturnMoreThanDeposit(0,1957414557617622995)
    deposit(13,false,3441335788914495287800899557082375368528531556117096880894049040840472934976)
    borrowShares(42,false,2)
    maxRedeem_correctMax(1)
    cannotLiquidateASolventUser(0,false) Time delay: 150273 seconds Block delay: 4354
    depositAssetType(0,false,115419216813914548806106100049,0) Time delay: 233520 seconds Block delay: 19164
    maxRedeem_correctMax(0) Time delay: 322320 seconds Block delay: 49849
    transitionCollateral_doesNotResultInMoreShares(0,false,91151606349439528474,0)


    forge test -vv --ffi --mt test_echidna_scenario_transitionCollateral_1
    */
    function test_echidna_scenario_transitionCollateral_1() public {
        __previewDeposit_doesNotReturnMoreThanDeposit(0,1957414557617622995);
        __deposit(13,false,3441335788914495287800899557082375368528531556117096880894049040840472934976);
        __borrowShares(42,false,2);
        __maxRedeem_correctMax(1);

        __timeDelay(150273);
        // __cannotLiquidateASolventUser(0,false); //  Time delay: 150273 seconds Block delay: 4354

        __timeDelay(233520);
        __depositAssetType(0,false,115419216813914548806106100049,0); // Time delay: 233520 seconds Block delay: 19164

        __timeDelay(322320);
        __maxRedeem_correctMax(0); // Time delay: 322320 seconds Block delay: 49849

        __transitionCollateral_doesNotResultInMoreShares(0,false,91151606349439528474,0);
    }
    
    /*
    transitionCollateral_doesNotResultInMoreShares(uint8,bool,uint256,uint8): failed!💥  
  Call sequence, shrinking 6/500:
    __depositNeverMintsZeroShares(0,false,291242197)
    __depositNeverMintsZeroShares(161,true,22168924613129761549643809883710869859261573373213864899764932836300336298504)
    __borrow(2,false,257715079)
    *wait* Time delay: 1 seconds Block delay: 1
    __deposit(0,false,171779519446128725026656172)
    __transitionCollateral_doesNotResultInMoreShares(0,false,139242359331505196953467599,1)

    forge test -vv --ffi --mt test_echidna_scenario_transitionCollateral_2

    */
    function test_echidna_scenario_transitionCollateral_2() public {
        __depositNeverMintsZeroShares(0,false,291242197);
        __depositNeverMintsZeroShares(161,true,22168924613129761549643809883710869859261573373213864899764932836300336298504);
        __borrow(2,false,257715079);
        // *wait* Time delay: 1 seconds Block delay: 1
        __timeDelay(1);
        __deposit(0,false,171779519446128725026656172);
        __transitionCollateral_doesNotResultInMoreShares(0,false,139242359331505196953467599,1);
    }

/*
transitionCollateral_doesNotResultInMoreShares(uint8,bool,uint256,uint8): failed!💥
  Call sequence, shrinking 30/500:
    EchidnaE2E.depositNeverMintsZeroShares(0,false,277384522)
    EchidnaE2E.depositNeverMintsZeroShares(161,true,22168924613129761549643809883710869859261573373213864899764932836300336298504)
    EchidnaE2E.borrow(2,false,257715079)
    *wait* Time delay: 1 seconds Block delay: 1
    EchidnaE2E.deposit(0,false,65708039052381260102903303)
    EchidnaE2E.transitionCollateral_doesNotResultInMoreShares(0,false,64112744701069629553371966,1)


    forge test -vv --ffi --mt test_echidna_scenario_transitionCollateral_3

    */
    function test_echidna_scenario_transitionCollateral_3() public {
        __depositNeverMintsZeroShares(0,false,277384522);
        __depositNeverMintsZeroShares(161,true,22168924613129761549643809883710869859261573373213864899764932836300336298504);
        __borrow(2,false,257715079);
        // *wait* Time delay: 1 seconds Block delay: 1
        __timeDelay(1);
        __deposit(0,false,65708039052381260102903303);
        __transitionCollateral_doesNotResultInMoreShares(0,false,64112744701069629553371966,1);
    }

/*
transitionCollateral_doesNotResultInMoreShares(uint8,bool,uint256,uint8): failed!💥
  Call sequence, shrinking 30/500:
    EchidnaE2E.depositNeverMintsZeroShares(0,false,277384522)
    EchidnaE2E.depositNeverMintsZeroShares(161,true,22168924613129761549643809883710869859261573373213864899764932836300336298504)
    EchidnaE2E.borrow(2,false,257715079)
    *wait* Time delay: 1 seconds Block delay: 1
    EchidnaE2E.deposit(0,false,65708039052381260102903303)
    EchidnaE2E.transitionCollateral_doesNotResultInMoreShares(0,false,64112744701069629553371966,1)


    forge test -vv --ffi --mt test_echidna_scenario_transitionCollateral_4

    case where we have loss of 23 wei of assets??

    */
    function test_echidna_scenario_transitionCollateral_4() public {
        __depositNeverMintsZeroShares(0,false,277384522);
        __depositNeverMintsZeroShares(161,true,22168924613129761549643809883710869859261573373213864899764932836300336298504);
        __borrow(2,false,257715079);
        // *wait* Time delay: 1 seconds Block delay: 1
        __timeDelay(1);
        __deposit(0,false,65708039052381260102903303);
        __transitionCollateral_doesNotResultInMoreShares(0,false,64112744701069629553371966,1);
    }
}
