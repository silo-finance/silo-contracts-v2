// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Strings} from "openzeppelin-contracts/utils/Strings.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {EchidnaMiddleman} from "./EchidnaMiddleman.sol";

/*
    forge test -vv --ffi --mc EchidnaScenariosTest
*/
contract EchidnaScenariosTest is EchidnaMiddleman {
    /*
mint(uint8,bool,uint256): passing
maxBorrow_correctReturnValue(uint8): failed!💥
Call sequence:
depositNeverMintsZeroShares(0,false,39962600816669483677151)
depositNeverMintsZeroShares(161,true,22168924613129761549643809883710869859261573373213864899764932836300336298504)
borrow(2,false,39858486983777211695540)
*wait* Time delay: 1 seconds Block delay: 1
maxBorrow_correctReturnValue(0)

Event sequence:
Panic(1): Using assert
LogString(«Actor selected index:0») from: 0xa329c0648769a73afac7f9381e08fb43dbea72
LogString(«Max Assets to borrow:339682116») from: 0xa329c0648769a73afac7f9381e08fb43dbea72
Transfer(339682116) from: 0xbd748c717ca30862991dc44aaf0b4db9f8de12da
Transfer(339682116) from: 0xcd9a70c13c88863ece51b302a77d2eb98fbbbd65
Borrow(339682116, 339682116) from: 0x74551568ff6d425a2ec2fb2975e47afc7de96d70
error Revert AboveMaxLtv ()
error Revert AboveMaxLtv ()
error Revert AboveMaxLtv ()

    forge test -vv --ffi --mt test_cover_echidna_scenario_1

    this test case covers the bug we had in maxBorrow
    */
    function test_cover_echidna_scenario_1() public {
        __depositNeverMintsZeroShares(0,false,39962600816669483677151);
        __depositNeverMintsZeroShares(161,true,22168924613129761549643809883710869859261573373213864899764932836300336298504);
        __borrow(2,false,39858486983777211695540);

        //        *wait* Time delay: 1 seconds Block delay: 1
        vm.warp(block.timestamp + 1);

        (uint256 maxAssets, uint256 shares) = __maxBorrow_correctReturnValue(0);

        assertEq(maxAssets, 33968211591454069532969, "echidna borrow amount (339682116)");
    }

    /*
maxRedeem_correctMax(uint8): failed!💥
  Call sequence, shrinking 316/500:
    mint(220,true,39843190113244004124792096928447682291)
    depositNeverMintsZeroShares(2,false,22786647965505400975764605899155696411742225287612091359740640699919114746382)
    borrowShares(32,true,20769187434139310514121985316880385)
    debtSharesNeverLargerThanDebt() Time delay: 2369 seconds Block delay: 4358
    maxRedeem_correctMax(4)

Revert NotEnoughLiquidity

    forge test -vv --ffi --mt test_cover_echidna_scenario_2

    this case covers the bug with maxRedeem
    */
    function test_cover_echidna_scenario_2() public {
        __mint(220,true,39843190113244004124792096928447682291);
        __depositNeverMintsZeroShares(2,false,22786647965505400975764605899155696411742225287612091359740640699919114746382);
        __borrowShares(32,true,20769187434139310514121985316880385);

        __timeDelay(2369, 4358);

        __debtSharesNeverLargerThanDebt(); // Time delay: 2369 seconds Block delay: 4358

        _dumpState(4);
        __maxRedeem_correctMax(4);
    }

    /*
maxBorrowShares_correctReturnValue(uint8): failed!💥
Call sequence, shrinking 294/500:
deposit(1,false,18362350053917916671701463106358)
previewDeposit_doesNotReturnMoreThanDeposit(44,5021491078257170633099496333274079409660413512867881700899062515742671857130)
mint(0,false,127287174252953083636439506782)
maxBorrow_correctReturnValue(21)
maxWithdraw_correctMax(110)
previewDeposit_doesNotReturnMoreThanDeposit(2,62718039246364723308705975150828086672) Time delay: 3865 seconds Block delay: 1791
maxBorrowShares_correctReturnValue(1)

Revert AboveMaxLtv ()

    forge test -vv --ffi --mt test_cover_echidna_scenario_3

    this case covers the bug with maxBorrowShare
    */
    function test_cover_echidna_scenario_3() public {
        __deposit(1,false,18362350053917916671701463106358);
        __previewDeposit_doesNotReturnMoreThanDeposit(44,5021491078257170633099496333274079409660413512867881700899062515742671857130);
        __mint(0,false,127287174252953083636439506782);
        __maxBorrow_correctReturnValue(21);
        __maxWithdraw_correctMax(110);

        __timeDelay(3865, 1791);
        // Time delay: 3865 seconds Block delay: 1791
        __previewDeposit_doesNotReturnMoreThanDeposit(2,62718039246364723308705975150828086672); // Time delay: 3865 seconds Block delay: 1791

        __maxBorrowShares_correctReturnValue(1);
    }
}
