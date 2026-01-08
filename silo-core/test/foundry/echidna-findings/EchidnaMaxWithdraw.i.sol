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
        __mintAssetType(2, false, 1735307726803407988754159223487, 0);
        __previewDeposit_doesNotReturnMoreThanDeposit(0, 66388211008287927515433611);
        __depositAssetType(0, false, 40985832250508332903885335837505434310360998126818377392697693682806386770, 1);
        __borrowShares(120, 3, 0);
        __maxBorrowShares_correctReturnValue(170);

        //        __cannotLiquidateASolventUser(0,false); // Time delay: 579336 seconds Block delay: 15624
        __timeDelay(579336);

        __debtSharesNeverLargerThanDebt(); // Time delay: 491278 seconds Block delay: 18078
        __timeDelay(491278);

        __previewDeposit_doesNotReturnMoreThanDeposit(
            2, 71994004506247621724349925153728615743520108634673265697683206836729824850
        );

        __maxWithdraw_correctMax(135);
    }

    /*
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_EchidnaDefaulting_assert_LENDING_INVARIANT_B
    */
    function test_EchidnaDefaulting_assert_LENDING_INVARIANT_B() public {
        _delay(0x2d67e, 0x94d4);
    
        /*Target*/__flashLoan(33997933614, 59720891045440504036478328204482, 255, 255);
        _delay(0x1116d, 0x696a);
    
        /*Target*/__flashLoan(141, 3490240572148739115283646203988286917862725275911766428893275924779700305261, 223, 255);
        _delay(0x8f9df, 0x13e);
    
        /*Target*/__setDaoFee(951, 4369999);
        _delay(0x177, 0xe0d0);
    
        /*Target*/__accrueInterestForSilo(255);
        _delay(0x64ad6, 0x185a);
    
        /*Target*/__repayShares(41554817557094186064533894015130926811343312575249145325483587144519081482914, 58, 255);
        _delay(0x63f8d, 0x7e5b);
    
        /*Target*/__mint(365045, 254, 53, 255);
        _delay(0x75, 0xdd0);
    
        /*Target*/__repayShares(311072328, 255, 255);
        _delay(0x42655, 0x5b6b);
    
        /*Target*/__liquidationCallByDefaulting(37422699887768669765783046586599516837044989231599567131519487622971353741226, RandomGenerator(255, 74, 255));
        _delay(0x8af1a, 0x320);
    
        /*Target*/__increaseReceiveAllowance(346, 0, 5);
        _delay(0x142ef, 0x1740);
    
        /*Target*/__liquidationCall(67728972471006198986298227812770245613331157852673164503068484645059995572823, false, RandomGenerator(160, 157, 255));
        _delay(0x6a2ce, 0x8ffb);
    
        /*Target*/__repay(4369999, 189, 91);
        _delay(0x4a9a4, 0x2f15);
    
        /*Target*/__transfer(1524785993, 255, 11);
        _delay(0x1051, 0x7210);
    
        /*Target*/__repayShares(95892808007310130461726393477978320535191969378337819859309698314584970665759, 191, 160);
        _delay(0x62e05, 0xff);
    
        /*Target*/__liquidationCallByDefaulting(31012643420486718865104172824785518880978806563527511629903994531281080040044, RandomGenerator(114, 255, 197));
        _delay(0x103ef, 0x95ce);
    
        /*Target*/__borrowShares(4370001, 13, 255);
        _delay(0x65373, 0x5c65);
    
        /*Target*/__approve(1524785993, 255, 252);
        _delay(0x65410, 0xdefe);
    
        /*Target*/__repayShares(494, 179, 255);
        _delay(0x65373, 0x7630);
    
        /*Target*/__liquidationCall(4370000, false, RandomGenerator(255, 255, 32));
        _delay(0x307c6, 0x20ff);
    
        /*Target*/__transitionCollateral(115792089237316195423570985008687907853269984665640564039457584007913129639931, RandomGenerator(255, 190, 255));
        _delay(0x475d0, 0xa663);
    
        /*Target*/__liquidationCallByDefaulting(102534336929198877321702095445937357962574072565302534037659811884723175914078, RandomGenerator(76, 83, 255));
        _delay(0x6fa94, 0xe59f);
    
        /*Target*/__setReceiveApproval(4370000, 14, 57);
        _delay(0x6a9f7, 0x5c65);
    
        /*Target*/__setReceiveApproval(384, 91, 255);
        _delay(0x6fde0, 0x2c55);
    
        /*Target*/__approve(27148545692374155322291941503308178963530265868509743399535280528644029865215, 255, 235);
        _delay(0x62e05, 0x2ea6);
    
        /*Target*/__deposit(4369999, 255, 153, 136);
        _delay(0x66815, 0x20ff);
    
        /*Target*/__borrowShares(27911167801869684515744473000929147500345948956948960096806928214355651970206, 123, 222);
        _delay(0x1b73c, 0x7f);
    
        /*Target*/__redeem(69804035102822899763494712667121677177454622072505461205402417414177107505946, 60, 255, 255);
        _delay(0x1b73c, 0x7fff);
    
        /*Target*/__decreaseReceiveAllowance(1524785993, 71, 255);
        _delay(0x4daf5, 0xd38b);
    
        // /*Target*/__MIN_PRICE();
        _delay(0x576ad, 0xd1ae);
    
        /*Target*/__redeem(115792089237316195423570985008687907853269984665640564039457584007913129639933, 14, 136, 28);
        _delay(0x4daf5, 0xcfae);
    
        /*Target*/__decreaseReceiveAllowance(4369999, 255, 254);
        _delay(0x11d50, 0x2e81);
    
        /*Target*/__approve(84650142505917377559005533300925546105801758978925122315120759991916446545247, 135, 162);
        _delay(0x3e1ce, 0xd13a);
    
        /*Target*/__withdraw(1524785992, 255, 97, 106);
        _delay(0x7d1b7, 0x87a0);
    
        /*Target*/__decreaseReceiveAllowance(4370000, 255, 255);
        _delay(0x475d0, 0xe142);
    
        /*Target*/__setOraclePrice(58160580489700127668469870347581330043227444339977370134949532548299805865648, 255);
        _delay(0x6c82f, 0xa4a9);
    
        /*Target*/__deposit(79035511232824199074153207416910770763102106856489416349797366457525449527355, 186, 255, 255);
        _delay(0x189e3, 0x753b);
    
        /*Target*/__accrueInterestForBothSilos();
        _delay(0x65410, 0x5d4d);
    
        /*Target*/__withdraw(530780513563034613288841675059373940962231014741194921737403, 239, 255, 255);
        _delay(0x77bd0, 0x94d4);
    
        /*Target*/__accrueInterestForBothSilos();
        _delay(0x4daf5, 0x20);
    
        /*Target*/__liquidationCallByDefaulting(115792089237316195423570985008687907853269984665640564039457584007913129639935, RandomGenerator(255, 255, 255));
        _delay(0x3340a, 0x7f);
    
        /*Target*/__accrueInterestForBothSilos();
        _delay(0x8dde9, 0x116e);
    
        /*Target*/__receiveAllowance(29882650456281084738190043830201979887566836706330072603560922513535419521132, 228, 255, 204);
        _delay(0x65ba5, 0xa475);
    
        /*Target*/__accrueInterestForBothSilos();
        _delay(0x1cae0, 0xea4d);
    
        /*Target*/__repayShares(122794517411283, 254, 169);
        _delay(0x6d464, 0x87a0);
    
        /*Target*/__liquidationCall(110342258604813883136076491391080051692563040975227526460641868343995084633246, false, RandomGenerator(12, 255, 255));
        _delay(0x74d9f, 0xb2fb);
    
        /*Target*/__mint(28649857434211785716785075571150725017899301465750003284002157044320271768204, 105, 38, 254);
        _delay(0x7fff, 0x1740);
    
        /*Target*/__repayShares(71708458556377148034738526920072027328540892681006375790390644571284132856343, 193, 166);
        _delay(0x3256a, 0xd38b);
    
        // /*Target*/__MAX_PRICE();
        _delay(0x4daf5, 0x95ce);
    
        /*Target*/__assert_BORROWING_HSPOST_D(252, 255);
        _delay(0xb3d0, 0xd13a);
    
        /*Target*/__setOraclePrice(95081893068143359407883104546296025957664557752771364132166348654363223148495, 65);
        _delay(0x65373, 0x9de);
    
        /*Target*/__liquidationCallByDefaulting(76597552767090721918719815898960607117313991696237260016271266784287660272610, RandomGenerator(87, 179, 255));
        _delay(0x4eac7, 0xe4d);
    
        /*Target*/__accrueInterestForBothSilos();
        _delay(0x7d1b7, 0xcf13);
    
        // /*Target*/__MIN_PRICE();
        _delay(0x7f7c2, 0xff);
    
        /*Target*/__repay(96630375201925410040082539982734416186641267585699916877556906461429592050050, 213, 255);
        _delay(0x103ef, 0x107f);
    
        /*Target*/__liquidationCallByDefaulting(22219085446096088425086531464894483902672762533719580988545515823426312680099, RandomGenerator(255, 240, 255));
        _delay(0x46b47, 0xd619);
    
        /*Target*/__repay(60330835776423846165004771220335477365446027906003784432952490792006788440388, 34, 241);
        _delay(0x8f9df, 0x13be);
    
        /*Target*/__assert_BORROWING_HSPOST_D(220, 255);
        _delay(0x70f0, 0x5c65);
    
        /*Target*/__deposit(1524785992, 45, 192, 255);
        _delay(0x5dfb0, 0x2f15);
    
        /*Target*/__assertBORROWING_HSPOST_F(255, 137);
        _delay(0x1051, 0x7d93);
    
        /*Target*/__increaseReceiveAllowance(115792089237316195423570985008687907853269984665640564039457584007913129639934, 255, 255);
        _delay(0x142ef, 0xd0cb);
    
        /*Target*/__setReceiveApproval(115792089237316195423570985008687907853269984665640564039457584007913129639935, 172, 255);
        _delay(0x76ea6, 0x9cf);
    
        /*Target*/__setOraclePrice(115792089237316195423570985008687907853269984665640564039457584007913129639934, 161);
        _delay(0x5f467, 0x89b0);
    
        /*Target*/__borrow(1524785993, 187, 122);
        _delay(0x62123, 0x1c9b);
    
        /*Target*/__assert_LENDING_INVARIANT_B(255, 36);
        _delay(0xb056, 0x753b);
    
        /*Target*/__redeem(106781997506895828704624214719419180173846986714878297331960770258476324553957, 0, 255, 1);
        _delay(0x8345, 0x4ddd);
    
        /*Target*/__assert_BORROWING_HSPOST_D(252, 255);
        _delay(0x3e1ce, 0xcfae);
    
        /*Target*/__mint(8833740862598790822298872322557078511982463963928588332032819512705882315246, 247, 118, 255);
        _delay(0x6b721, 0xe59f);
    
        /*Target*/__assertBORROWING_HSPOST_F(255, 255);
        _delay(0x6123, 0x320);
    
        /*Target*/__setReceiveApproval(42433951474074729361621982518820040054100203943647270879125385874743773798748, 130, 24);
        _delay(0x582b0, 0x20ff);
    
        /*Target*/__approve(82109049031960918442738176079186229578228170818505220915176958281990161257318, 255, 255);
        _delay(0x1f113, 0x2f7b);
    
        /*Target*/__increaseReceiveAllowance(68, 25, 255);
        _delay(0xffff, 0xd8f2);
    
        /*Target*/__repayShares(0, 181, 255);
        _delay(0x24b01, 0x30cd);
    
        /*Target*/__assert_SILO_HSPOST_D(255);
        _delay(0x214c8, 0xcfae);
    
        /*Target*/__accrueInterestForBothSilos();
        _delay(0x329b9, 0x320);
    
        /*Target*/__borrow(4369999, 15, 42);
        _delay(0x1b73c, 0x440);
    
        /*Target*/__liquidationCallByDefaulting(565, RandomGenerator(61, 14, 255));
        _delay(0x5408b, 0x26ee);
    
        /*Target*/__receiveAllowance(1524785992, 224, 255, 22);
        _delay(0x212f1, 0x1414);
    
        /*Target*/__increaseReceiveAllowance(61337461536744140313660380324818011942477261825176834788369124471526107825961, 255, 255);
        _delay(0x6b504, 0x552);
    
        /*Target*/__receiveAllowance(1524785991, 151, 255, 239);
        _delay(0x4a0f1, 0xb556);
    
        // /*Target*/__MAX_PRICE();
        _delay(0x4eb46, 0x8980);
    
        /*Target*/__liquidationCall(1524785991, false, RandomGenerator(3, 255, 255));
        _delay(0x42655, 0xd619);
    
        /*Target*/__repayShares(7820336472698723259836837139630046202385603710161591492277320897963474743784, 68, 255);
        _delay(0x48651, 0x463);
    
        /*Target*/__assertBORROWING_HSPOST_F(140, 0);
        _delay(0x52e28, 0xd619);
    
        /*Target*/__setReceiveApproval(416, 128, 33);
        _delay(0x1ae49, 0x5c65);
    
        /*Target*/__assert_LENDING_INVARIANT_B(255, 156);
        _delay(0x75d98, 0x7f);
    
        /*Target*/__approve(62210178003067872032363862593697997573465648818003862600306593549124497195450, 80, 135);
        _delay(0x46b47, 0x8ffb);
    
        /*Target*/__accrueInterestForSilo(14);
        _delay(0x81f7, 0x1a41);
    
        /*Target*/__assert_BORROWING_HSPOST_D(49, 255);
        _delay(0x1cae0, 0x1320);
    
        /*Target*/__liquidationCall(4370001, false, RandomGenerator(149, 21, 118));
        _delay(0x7b6a, 0x9d0);
    
        /*Target*/__redeem(4370000, 255, 26, 215);
        _delay(0x7d1b7, 0x755a);
    
        /*Target*/__borrow(65585194715669205132739287491084670852465903559164611781706710043332307970603, 255, 81);
        _delay(0x6a2ce, 0xcf13);
    
        /*Target*/__mint(1524785991, 137, 255, 228);
        _delay(0x576ad, 0xdefe);
    
        /*Target*/__receiveAllowance(262117389025040960656941050858116432210996162521186349, 255, 255, 24);
        _delay(0x1cae0, 0x7630);
    
        /*Target*/__decreaseReceiveAllowance(115792089237316195423570985008687907853269984665640564039457584007913129639933, 0, 17);
        _delay(0x4a0f1, 0x26c0);
    
        /*Target*/__setReceiveApproval(38619747731699152230644537703097785233519251829562314810378839206026474715870, 134, 255);
        _delay(0x2f08c, 0x753b);
    
        /*Target*/__mint(0, 255, 202, 255);
        _delay(0x2fa33, 0x6b0c);
    
        /*Target*/__transferFrom(4370001, 172, 255, 3);
        _delay(0xff, 0x279e);
    
        /*Target*/__borrow(115792089237316195423570985008687907853269984665640564039457584007913129639932, 255, 41);
        _delay(0x214c8, 0xd8f2);
    
        /*Target*/__liquidationCallByDefaulting(19440281052238228046917137526546382794030784465697728187592931051976865117079, RandomGenerator(43, 255, 0));
        _delay(0x28928, 0xc107);
    
        /*Target*/__assert_BORROWING_HSPOST_D(255, 185);
        _delay(0x307c6, 0x5b6b);
    
        /*Target*/__repay(4370001, 227, 173);
        _delay(0x77bce, 0x5aeb);
    
        /*Target*/__assertBORROWING_HSPOST_F(255, 169);
        _delay(0x1f113, 0x3c08);
    
        /*Target*/__transfer(4370001, 85, 255);
        _delay(0x51251, 0x2c55);
    
        /*Target*/__accrueInterestForSilo(181);
        _delay(0x142ef, 0xa475);
    
        /*Target*/__borrowShares(0, 255, 255);
        _delay(0x41a2, 0xa4f5);
    
        /*Target*/__transitionCollateral(884, RandomGenerator(110, 255, 46));
        _delay(0x5bd20, 0x2e32);
    
        /*Target*/__increaseReceiveAllowance(1524785993, 62, 255);
        _delay(0x62e05, 0x5c65);
    
        /*Target*/__transfer(22944587289367568746250287521237882356293243266981018442209355429155904556762, 60, 213);
        _delay(0xb056, 0xc854);
    
        /*Target*/__assert_SILO_HSPOST_D(255);
        _delay(0x7d1b7, 0x26c0);
    
        /*Target*/__accrueInterest(56);
        _delay(0x7cf4e, 0x277e);
    
        /*Target*/__mint(1524785992, 108, 255, 255);
        _delay(0x4a55, 0xb2fb);
    
        /*Target*/__mint(1524785992, 47, 255, 189);
        _delay(0x3340a, 0x597d);
    
        /*Target*/__accrueInterestForSilo(230);
        _delay(0x62123, 0xd1ae);
    
        /*Target*/__assertBORROWING_HSPOST_F(255, 255);
        _delay(0x46b47, 0x1320);
    
        // /*Target*/__MAX_PRICE();
        _delay(0x3340a, 0xd619);
    
        /*Target*/__liquidationCallByDefaulting(1524785993, RandomGenerator(125, 252, 255));
        _delay(0x7f467, 0x3b9a);
    
        /*Target*/__repay(1524785992, 117, 255);
        _delay(0x81f7, 0x753b);
    
        /*Target*/__liquidationCallByDefaulting(0, RandomGenerator(56, 40, 126));
        _delay(0x6d464, 0xea4f);
    
        /*Target*/__assert_SILO_HSPOST_D(115);
        _delay(0x4a55, 0x30cd);
    
        /*Target*/__repay(736, 251, 191);
        _delay(0x1c18d, 0xe5d2);
    
        /*Target*/__repay(4369999, 255, 255);
        _delay(0x80772, 0x94d4);
    
        /*Target*/__liquidationCall(106723709733403423642092629950696877456986098004742726315960636427595273783252, true, RandomGenerator(156, 255, 195));
        _delay(0x142f0, 0x5caa);
    
        /*Target*/__liquidationCallByDefaulting(41156989385870650511201598624304639187324262764121025257385690308482112243436, RandomGenerator(157, 255, 138));
        _delay(0x142ef, 0x7630);
    
        /*Target*/__liquidationCallByDefaulting(66505786955507820238401180420926220756841145654195074064083144180067794290705, RandomGenerator(255, 255, 83));
        _delay(0x29247, 0x8ffb);
    
        /*Target*/__setReceiveApproval(69826747835200643904221383016200815059410222286299230890513773756116249034947, 255, 119);
        _delay(0x804a4, 0xff);
    
        /*Target*/__borrowShares(1524785991, 29, 255);
        _delay(0x6b504, 0x440);
    
        /*Target*/__borrowShares(4369999, 198, 255);
        _delay(0x4694f, 0x30cd);
    
        // /*Target*/__MAX_PRICE();
        _delay(0x6123, 0x755a);
    
        /*Target*/__mint(1524785991, 187, 225, 24);
        _delay(0x4a9a4, 0x6c9c);
    
        /*Target*/__receiveAllowance(88968095358741298776878563895436183321799220856386626409567278712462649867910, 255, 212, 255);
        _delay(0x65410, 0xea96);
    
        /*Target*/__accrueInterestForSilo(247);
        _delay(0x307c6, 0x5ef7);
    
        /*Target*/__accrueInterestForBothSilos();
        _delay(0x42655, 0x58ab);
    
        /*Target*/__mint(1524785991, 24, 21, 194);
        _delay(0x8f9df, 0x5daa);
    
        /*Target*/__mint(1524785991, 154, 16, 68);
        _delay(0x80772, 0x755a);
    
        /*Target*/__transitionCollateral(21409319520113706690308350931635367003876811136146692412440777169173698490652, RandomGenerator(255, 255, 176));
        _delay(0x2621e, 0xb31c);
    
        /*Target*/__setReceiveApproval(77337307715719400453942886950771053198709764232338099106449501237073269072113, 255, 255);
        _delay(0x1051, 0xe8a0);
    
        // /*Target*/__MAX_PRICE();
        _delay(0x74813, 0xdfb9);
    
        /*Target*/__repay(4369999, 255, 255);
        _delay(0x51251, 0x26ee);
    
        /*Target*/__setReceiveApproval(105048994818534055222674767794995888465534041843482300461275270909882071990677, 255, 222);
        _delay(0x142ee, 0x3c08);
    
        /*Target*/__transferFrom(10193277817637005360558734678678705754054357859575678243450813619098131614745, 52, 244, 255);
        _delay(0x52be8, 0x3032);
    
        /*Target*/__setOraclePrice(1524785992, 70);
        _delay(0x11d50, 0xea4d);
    
        /*Target*/__repayShares(1524785993, 254, 255);
        _delay(0x6b721, 0x1320);
    
        /*Target*/__deposit(37294160861839470945715928029075211652654478420596236659019067592348287092651, 163, 255, 255);
        _delay(0x329b9, 0x116e);
    
        /*Target*/__receiveAllowance(485, 255, 14, 255);
        _delay(0x94ab, 0x5b6b);
    
        // /*Target*/__MIN_PRICE();
        _delay(0x2a045, 0x5ef7);
    
        /*Target*/__transferFrom(115792089237316195423570985008687907853269984665640564039457584007913129639935, 255, 255, 255);
        _delay(0x64ad5, 0xe8a0);
    
        /*Target*/__liquidationCallByDefaulting(62642639977860731642902822164935719331006320956980023718404314800998625436649, RandomGenerator(62, 255, 253));
        _delay(0x37272, 0x7660);
    
        /*Target*/__assert_BORROWING_HSPOST_D(255, 163);
        _delay(0x41a2, 0xa663);
    
        /*Target*/__approve(1524785991, 128, 76);
        _delay(0x4694f, 0xc85a);
    
        /*Target*/__accrueInterest(69);
        _delay(0x77bd0, 0x5ef7);
    
        /*Target*/__approve(115792089237316195423570985008687907853269984665640564039457584007913129639934, 255, 122);
        _delay(0x4694f, 0x95ce);
    
        /*Target*/__liquidationCallByDefaulting(72142487059008203792313838954728895985149319951503394542868515209319545467410, RandomGenerator(231, 99, 179));
        _delay(0x52be8, 0x13bd);
    
        /*Target*/__accrueInterestForSilo(247);
        _delay(0x214ca, 0x30cd);
    
        /*Target*/__transitionCollateral(2905524548308743158965956862307356415408958468470663656910024000301346978550, RandomGenerator(255, 0, 99));
        _delay(0x307c6, 0x2e32);
    
        /*Target*/__transitionCollateral(115792089237316195423570985008687907853269984665640564039457584007913129639935, RandomGenerator(255, 115, 206));
        _delay(0x5f467, 0x5aeb);
    
        /*Target*/__borrowShares(1524785992, 255, 128);
        _delay(0x307c6, 0x3c09);
    
        // /*Target*/__MAX_PRICE();
        _delay(0x2a045, 0xd38b);
    
        /*Target*/__transfer(4912473, 156, 117);
        _delay(0xff, 0x9cf);
    
        // /*Target*/__MAX_PRICE();
        _delay(0x2a045, 0x9cf);
    
        // /*Target*/__MAX_PRICE();
        _delay(0x576ad, 0xd1ae);
    
        /*Target*/__transferFrom(90318476213917949728386927160082259735316458568522904138088398235816897711407, 255, 255, 125);
        _delay(0x76ea6, 0x87a0);
    
        /*Target*/__increaseReceiveAllowance(4369999, 99, 255);
        _delay(0x85b27, 0x94d4);
    
        /*Target*/__borrow(113798795689622209078082902835866625882421236862259084249738652943360546215072, 44, 255);
        _delay(0x11d50, 0x2ea6);
    
        /*Target*/__transferFrom(110083703931358221363076659603373759752367532300390439908929586863011616324167, 17, 252, 255);
        _delay(0x3256a, 0x8980);
    
        /*Target*/__assert_BORROWING_HSPOST_D(166, 90);
        _delay(0x81f7, 0x755a);
    
        /*Target*/__transitionCollateral(9185236013203816443548148432183170538667391471045253198729267642083338298609, RandomGenerator(255, 255, 229));
        _delay(0x6a2ce, 0xd13a);
    
        /*Target*/__assert_LENDING_INVARIANT_B(20, 192);
        _delay(0x42655, 0x231);
    
        /*Target*/__liquidationCallByDefaulting(83827132201277929604310278461769535334031346570138975986843818449008384355583, RandomGenerator(35, 255, 67));
        _delay(0x5617a, 0x1c9b);
    
        /*Target*/__accrueInterest(255);
        _delay(0x3340a, 0x89b0);
    
        /*Target*/__liquidationCall(115792089237316195423570985008687907853269984665640564039457584007913129639935, false, RandomGenerator(255, 255, 169));
        _delay(0x712e4, 0x9d0);
    
        /*Target*/__liquidationCallByDefaulting(115792089237316195423570985008687907853269984665640564039457584007913129639935, RandomGenerator(255, 40, 64));
        _delay(0x43af0, 0xa663);
    
        /*Target*/__transitionCollateral(5118569183195425567126660190276278917075707430839223737981446780898544030189, RandomGenerator(111, 255, 42));
        _delay(0x75d98, 0x769a);
    
        /*Target*/__borrowShares(4370001, 150, 255);
        _delay(0x80772, 0xa4f5);
    
        /*Target*/__receiveAllowance(15034577099901710996919593284599078084840332859386219662641994623747670967148, 112, 227, 11);
        _delay(0x4694f, 0xdcf6);
    
        // /*Target*/__MIN_PRICE();
        _delay(0x7cf4e, 0x9de);
    
        /*Target*/__liquidationCallByDefaulting(22311278005040445027574342426498668344330648383954249661449739558162887707303, RandomGenerator(8, 255, 18));
        _delay(0xb056, 0x13bd);
    
        /*Target*/__receiveAllowance(45850619002861701817056430916337683895700250925567096412401997802148956417440, 125, 255, 53);
        _delay(0x7f467, 0x20ff);
    
        /*Target*/__assert_SILO_HSPOST_D(255);
        _delay(0x5eb90, 0x13be);
    
        /*Target*/__transferFrom(90508370297569908360089741359687802433805485817034804351043343463550528335829, 191, 46, 70);
        _delay(0x94ab, 0x3032);
    
        /*Target*/__assertBORROWING_HSPOST_F(255, 255);
        _delay(0x103ef, 0xeb6b);
    
        // /*Target*/__MAX_PRICE();
        _delay(0x63720, 0x619b);
    
        /*Target*/__liquidationCall(52143517035722306241620094494644035298324747384704421554497690072878146922462, true, RandomGenerator(230, 255, 255));
        _delay(0x214ca, 0x3c07);
    
        /*Target*/__decreaseReceiveAllowance(4370001, 162, 255);
        _delay(0x214c8, 0xa475);
    
        /*Target*/__assert_BORROWING_HSPOST_D(193, 112);
        _delay(0x28928, 0xeb6b);
    
        /*Target*/__accrueInterestForBothSilos();
        _delay(0x212f1, 0x116e);
    
        /*Target*/__borrow(95712136588299355648674910592899302043562829991942056757117289105891532633412, 115, 255);
        _delay(0x37272, 0x2233);
    
        /*Target*/__withdraw(42958727274043012777606106640142975125725909267727616435433289209571573629132, 10, 255, 164);
        _delay(0x48a23, 0x1c9b);
    
        /*Target*/__accrueInterest(255);
        _delay(0x74d9f, 0xe4d);
    
        /*Target*/__liquidationCall(12534804810458885577279800138304601393139274961850757441096174455635091621820, true, RandomGenerator(255, 194, 255));
        _delay(0x46b47, 0xd0cb);
    
        /*Target*/__borrowShares(4370000, 255, 170);
        _delay(0x64ad5, 0xe8a0);
    
        /*Target*/__increaseReceiveAllowance(874424080892720, 14, 0);
        _delay(0x668ee, 0x30cd);
    
        /*Target*/__assert_LENDING_INVARIANT_B(171, 255);
    }

    function _delay(uint256 timeInSeconds, uint256 numBlocks) internal {
        vm.warp(block.timestamp + timeInSeconds);
        vm.roll(block.number + numBlocks);
    }
}
