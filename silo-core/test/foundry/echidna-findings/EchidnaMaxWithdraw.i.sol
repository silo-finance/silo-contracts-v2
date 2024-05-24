// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Strings} from "openzeppelin5/utils/Strings.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {EchidnaMiddleman} from "./EchidnaMiddleman.sol";

/*
    forge test -vv --ffi --mc EchidnaMaxWithdrawTest
*/
contract EchidnaMaxWithdrawTest is EchidnaMiddleman {
    /*
maxWithdraw_correctMax(uint8): failed!💥
  Call sequence, shrinking 302/500:
    mintAssetType(2,false,10752370530470213059098506752467820,0)
    previewDeposit_doesNotReturnMoreThanDeposit(0,6838135870216164907095671941)
    deposit(58,false,35781036886328911185258360822510867381731575877522337521358861389498556084611)
    borrowShares(156,false,2)
    maxBorrowShares_correctReturnValue(11)
    vault1() Time delay: 425434 seconds Block delay: 3572
    debtSharesNeverLargerThanDebt() Time delay: 491278 seconds Block delay: 18078
    previewDeposit_doesNotReturnMoreThanDeposit(1,425891792695868665691774591731259659386611772883611823553717521737151607469) Time delay: 49176 seconds Block delay: 406
    maxWithdraw_correctMax(15)

    forge test -vv --ffi --mt test_echidna_scenario_maxWithdraw_correctMax1
    */
    function test_echidna_scenario_maxWithdraw_correctMax1() public {
        __mintAssetType(2,false,10752370530470213059098506752467820,0);
        __previewDeposit_doesNotReturnMoreThanDeposit(0,6838135870216164907095671941);
        __deposit(58,false,35781036886328911185258360822510867381731575877522337521358861389498556084611);
        __borrowShares(156,false,2);
        __maxBorrowShares_correctReturnValue(11);
        // vault1(); // Time delay: 425434 seconds Block delay: 3572
        __timeDelay(425434);
        __debtSharesNeverLargerThanDebt(); // Time delay: 491278 seconds Block delay: 18078
        __previewDeposit_doesNotReturnMoreThanDeposit(1,425891792695868665691774591731259659386611772883611823553717521737151607469);

        // Time delay: 49176 seconds Block delay: 406
        __timeDelay(49176);
        __maxWithdraw_correctMax(15);
    }

/*
maxWithdraw_correctMax(uint8): failed!💥
  Call sequence, shrinking 38/500:
    EchidnaE2E.mintAssetType(2,false,479936290768928286288619590199269,0)
    EchidnaE2E.previewDeposit_doesNotReturnMoreThanDeposit(0,130149798205058114997447095)
    EchidnaE2E.debtSharesNeverLargerThanDebt()
    *wait*
    EchidnaE2E.depositAssetType(0,false,28114739567946133799942713426681725785291273777957521719307878693967289427,1)
    EchidnaE2E.cannotLiquidateASolventUser(20,false)
    EchidnaE2E.deposit(12,false,24428929480309915595709971606621732836321705326069162901568460876476539767704)
    EchidnaE2E.repayNeverReturnsZeroAssets(2,false,4)
    EchidnaE2E.borrowShares(120,false,1)
    EchidnaE2E.maxBorrowShares_correctReturnValue(170)
    *wait* Time delay: 189583 seconds Block delay: 4923
    EchidnaE2E.maxRedeem_correctMax(7)
    *wait*
    EchidnaE2E.cannotLiquidateASolventUser(0,false) Time delay: 579336 seconds Block delay: 15624
    EchidnaE2E.previewDeposit_doesNotReturnMoreThanDeposit(20,115320030872300257577436910923755727994938587050944175707897351583648779882)
    EchidnaE2E.maxWithdraw_correctMax(135)


    forge test -vv --ffi --mt test_echidna_scenario_maxWithdraw_correctMax2

    this works, but failing on echidna
    */
    function test_echidna_scenario_maxWithdraw_correctMax2() public {
        __mintAssetType(2,false,479936290768928286288619590199269,0);
        __previewDeposit_doesNotReturnMoreThanDeposit(0,130149798205058114997447095);
        __debtSharesNeverLargerThanDebt();

        // *wait*
        __timeDelay(1);
        __depositAssetType(0,false,28114739567946133799942713426681725785291273777957521719307878693967289427,1);
        __cannotLiquidateASolventUser(20,false);
        __deposit(12,false,24428929480309915595709971606621732836321705326069162901568460876476539767704);
        __repayNeverReturnsZeroAssets(2,false,4);
        __borrowShares(120,false,1);
        __maxBorrowShares_correctReturnValue(170);
       //  *wait* Time delay: 189583 seconds Block delay: 4923
        __maxRedeem_correctMax(7);
        // *wait*
        __cannotLiquidateASolventUser(0,false); // Time delay: 579336 seconds Block delay: 15624
        __previewDeposit_doesNotReturnMoreThanDeposit(20,115320030872300257577436910923755727994938587050944175707897351583648779882);
        __maxWithdraw_correctMax(135);
    }
}
