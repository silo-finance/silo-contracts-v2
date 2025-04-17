// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {EchidnaMiddleman} from "./EchidnaMiddleman.sol";

/*
    forge test -vv --ffi --mc EchidnaMaxWithdrawTest
*/
contract EchidnaMaxWithdrawTest is EchidnaMiddleman {
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

    bug replicated, this test covers bug tha twas found by echidna
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

        __maxWithdraw_correctMax(135);
    }
}
