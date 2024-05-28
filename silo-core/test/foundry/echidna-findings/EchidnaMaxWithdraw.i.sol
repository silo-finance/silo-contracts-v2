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
  Call sequence, shrinking 16/500:
    EchidnaE2E.mintAssetType(2,false,1735307726803407988754159223487,0)
    EchidnaE2E.previewDeposit_doesNotReturnMoreThanDeposit(0,66388211008287927515433611)
    EchidnaE2E.depositAssetType(0,false,40985832250508332903885335837505434310360998126818377392697693682806386770,1)
    EchidnaE2E.borrowShares(120,false,3)
    EchidnaE2E.maxBorrowShares_correctReturnValue(170)
    EchidnaE2E.cannotLiquidateASolventUser(0,false) Time delay: 579336 seconds Block delay: 15624
    EchidnaE2E.debtSharesNeverLargerThanDebt() Time delay: 491278 seconds Block delay: 18078
    EchidnaE2E.previewDeposit_doesNotReturnMoreThanDeposit(2,71994004506247621724349925153728615743520108634673265697683206836729824850)
    EchidnaE2E.maxWithdraw_correctMax(135)


    forge test -vv --ffi --mt test_echidna_scenario_maxWithdraw_correctMax2

    bug replicated
    */
    function test_echidna_scenario_maxWithdraw_correctMax2() public {
        __mintAssetType(2,false,1735307726803407988754159223487,0);
        __previewDeposit_doesNotReturnMoreThanDeposit(0,66388211008287927515433611);
        __depositAssetType(0,false,40985832250508332903885335837505434310360998126818377392697693682806386770,1);
        __borrowShares(120,false,3);
        __maxBorrowShares_correctReturnValue(170);

//        __cannotLiquidateASolventUser(0,false); // Time delay: 579336 seconds Block delay: 15624
        __timeDelay(579336);

        __debtSharesNeverLargerThanDebt(); // Time delay: 491278 seconds Block delay: 18078
        __timeDelay(491278);

        __previewDeposit_doesNotReturnMoreThanDeposit(2,71994004506247621724349925153728615743520108634673265697683206836729824850);


        // this is a case when user has debt
        // we calculated max withdraw to be 207282918430713322852178022
        // but we can withdraw amount that is less by 1
        // Actor::withdraw(bool,uint256)(true, 207282918430713322852178022)
        __maxWithdraw_correctMax(135);

    }
}
