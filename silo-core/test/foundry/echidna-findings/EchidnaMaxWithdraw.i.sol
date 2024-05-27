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
  Call sequence, shrinking 44/500:
    EchidnaE2E.mintAssetType(1,false,92123405829686585701731477244389,0)
    EchidnaE2E.previewDeposit_doesNotReturnMoreThanDeposit(0,13869235684708946945932638)
    EchidnaE2E.depositAssetType(0,false,172937693249342302150464562545380959351466302635737185463272794637688466662,1)
    EchidnaE2E.borrowShares(120,false,1)
    EchidnaE2E.maxBorrowShares_correctReturnValue(1)
    EchidnaE2E.cannotLiquidateASolventUser(0,false) Time delay: 277131 seconds Block delay: 9472
    EchidnaE2E.debtSharesNeverLargerThanDebt() Time delay: 491278 seconds Block delay: 18078
    EchidnaE2E.previewDeposit_doesNotReturnMoreThanDeposit(28,38069533537078132925269718593014418013834630345951454545114315333832826820412)
    EchidnaE2E.maxWithdraw_correctMax(135)


    forge test -vv --ffi --mt test_echidna_scenario_maxWithdraw_correctMax2

    this is failing in Echidna, but it should be ignored, because `cannotLiquidateASolventUser` is executed on insolvent
    user, so there might be some inconsistency between Echidna and foundry
    */
    function test_skip_echidna_scenario_maxWithdraw_correctMax2() public {
        __mintAssetType(1,false,92123405829686585701731477244389,0);
        __previewDeposit_doesNotReturnMoreThanDeposit(0,13869235684708946945932638);
        __depositAssetType(0,false,172937693249342302150464562545380959351466302635737185463272794637688466662,1);
        __borrowShares(120,false,1);
        __maxBorrowShares_correctReturnValue(1);

        __timeDelay(277131);
        __cannotLiquidateASolventUser(0,false); // Time delay: 277131 seconds Block delay: 9472

        __timeDelay(491278);
        __debtSharesNeverLargerThanDebt(); // Time delay: 491278 seconds Block delay: 18078
        __previewDeposit_doesNotReturnMoreThanDeposit(28,38069533537078132925269718593014418013834630345951454545114315333832826820412);
        __maxWithdraw_correctMax(135);
    }
}
