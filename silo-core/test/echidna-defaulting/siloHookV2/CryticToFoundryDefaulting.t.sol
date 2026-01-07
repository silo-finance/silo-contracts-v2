// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {console2} from "forge-std/console2.sol";

// Libraries
import {Actor} from "silo-core/test/invariants/utils/Actor.sol";

// Contracts
import {SetupDefaulting} from "./SetupDefaulting.t.sol";
import {BaseHandlerDefaulting} from "./base/BaseHandlerDefaulting.t.sol";
import {DefaultBeforeAfterHooks} from "silo-core/test/invariants/hooks/DefaultBeforeAfterHooks.t.sol";
import {Invariants} from "silo-core/test/invariants/Invariants.t.sol";
import {DefaultingHandler} from "./handlers/user/DefaultingHandler.t.sol";

// solhint-disable function-max-lines, func-name-mixedcase

/*
 * Test suite that converts from  "fuzz tests" to foundry "unit tests"
 * The objective is to go from random values to hardcoded values that can be analyzed more easily
 */
contract CryticToFoundryDefaulting is Invariants, DefaultingHandler, SetupDefaulting {
    uint256 public constant DEFAULT_TIMESTAMP = 337812;

    CryticToFoundryDefaulting public DefaultingTester = this;
    CryticToFoundryDefaulting public Target = this;

    function setUp() public {
        // Deploy protocol contracts
        _setUp();

        // Deploy actors
        _setUpActors();

        // Initialize handler contracts
        _setUpHandlers();

        vm.warp(DEFAULT_TIMESTAMP);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                 FAILING INVARIANTS REPLAY                                 //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                              FAILING POSTCONDITIONS REPLAY                                //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /*
    FOUNDRY_PROFILE=echidna_defaulting forge test -vv --ffi --mt test_EchidnaDefaulting_empty
    */
    function test_EchidnaDefaulting_empty() public {}

    /*
    FOUNDRY_PROFILE=echidna_defaulting forge test -vv --ffi --mt test_EchidnaDefaulting_test1
    */
    function test_EchidnaDefaulting_test1() public {
        _delay(0x1116d, 0x696a);
        _setUpActor(USER1);
        Target.flashLoan(141, 3490240572148739115283646203988286917862725275911766428893275924779700305261, 223, 255);
        _delay(0x102e5, 0x13e);
        _setUpActor(USER1);
        Target.setDaoFee(951, 4369999);
        _delay(0x177, 0xe0d0);
        _setUpActor(USER1);
        Target.accrueInterestForSilo(255);
        _delay(0x64ad6, 0x185a);
        _setUpActor(USER1);
        Target.repayShares(7561462035222532974532095551967703960399998473087407174183811758551559655847, 1, 255);
        _delay(0x63f8d, 0x7e5b);
        _setUpActor(USER1);
        Target.mint(66484, 254, 53, 255);
        _setUpActor(USER1);
        Target.repayShares(311072328, 255, 255);
        _setUpActor(USER1);
        Target.increaseReceiveAllowance(346, 0, 5);
        _delay(0x142ef, 0x1740);
        _setUpActor(USER1);
        Target.liquidationCall(
            67728972471006198986298227812770245613331157852673164503068484645059995572823,
            false,
            RandomGenerator(160, 157, 112)
        );
        _delay(0x6a2ce, 0x8ffb);
        _setUpActor(USER1);
        Target.repay(4296435, 75, 8);
        _delay(0x25dc1, 0x2f15);
        _setUpActor(USER2);
        Target.transfer(1524785993, 255, 11);
        _delay(0x1051, 0x6aec);
        _setUpActor(USER1);
        Target.repayShares(95892808007310130461726393477978320535191969378337819859309698314584970665759, 191, 160);
        _delay(0x2882, 0x95ce);
        _setUpActor(USER3);
        Target.borrowShares(4370001, 13, 255);
        _delay(0x1c0d, 0xcf61);
        _setUpActor(USER1);
        Target.repayShares(208, 151, 255);
        _delay(0x341cb, 0x7630);
        _setUpActor(USER3);
        Target.liquidationCall(2978414, false, RandomGenerator(255, 11, 32));
        _delay(0x475d0, 0xc38);
        _setUpActor(USER3);
        Target.liquidationCallByDefaulting(
            15488639431677681209300535911472290413683691775383954251083307538996763138747,
            RandomGenerator(76, 79, 255)
        );
        _delay(0x6fa94, 0xe59f);
        _setUpActor(USER1);
        Target.setReceiveApproval(3489168, 3, 56);
        _delay(0x6a9f7, 0x5c65);
        _setUpActor(USER1);
        Target.setReceiveApproval(384, 91, 255);
        _delay(0x6fde0, 0x2c55);
        _setUpActor(USER2);
        Target.approve(1379116624264368345823313139787101050487986492767201646106423587746956426418, 244, 127);
        _delay(0x62e05, 0x2ea6);
        _setUpActor(USER1);
        Target.deposit(4369999, 255, 153, 136);
        _delay(0x465fa, 0x144c);
        _setUpActor(USER1);
        Target.borrowShares(27911167801869684515744473000929147500345948956948960096806928214355651970206, 123, 222);
        _setUpActor(USER1);
        Target.redeem(69804035102822899763494712667121677177454622072505461205402417414177107505946, 60, 255, 255);
        _delay(0x1b73c, 0x7fff);
        _setUpActor(USER3);
        Target.decreaseReceiveAllowance(287643688, 71, 209);
        _delay(0x4daf5, 0xd38b);
        _setUpActor(USER3);
        Target.MIN_PRICE();
        _delay(0x576ad, 0xd1ae);
        _setUpActor(USER1);
        Target.redeem(115792089237316195423570985008687907853269984665640564039457584007913129639933, 14, 136, 28);
        _delay(0x4daf5, 0xcfae);
        _setUpActor(USER2);
        Target.decreaseReceiveAllowance(1921674, 248, 27);
        _delay(0x11d50, 0x2e81);
        _setUpActor(USER1);
        Target.approve(84650142505917377559005533300925546105801758978925122315120759991916446545247, 135, 162);
        _setUpActor(USER1);
        Target.withdraw(1524785992, 255, 97, 106);
        _setUpActor(USER1);
        Target.decreaseReceiveAllowance(4370000, 255, 255);
        _setUpActor(USER2);
        Target.setOraclePrice(36209566528792079427148130845519629655671135851160895419073374734494726525269, 211);
        _delay(0x6c82f, 0xa4a9);
        _setUpActor(USER1);
        Target.deposit(13226490330474233242341190014999656022830109205116055905681125774109342921662, 186, 135, 255);
        _delay(0x189e3, 0x753b);
        _setUpActor(USER1);
        Target.accrueInterestForBothSilos();
        _delay(0x65410, 0x5d4d);
        _setUpActor(USER3);
        Target.withdraw(365415067496752609253333474404232625037090141443397665399592, 239, 112, 255);
        _delay(0x77bd0, 0x94d4);
        _setUpActor(USER3);
        Target.accrueInterestForBothSilos();
        _delay(0x4a144, 0x1f);
        _setUpActor(USER1);
        Target.liquidationCallByDefaulting(
            22891009478861957011728079747580742988773454701522581463169644632735904928140,
            RandomGenerator(255, 227, 217)
        );
        _delay(0x3340a, 0x7f);
        _setUpActor(USER1);
        Target.accrueInterestForBothSilos();
        _delay(0x8dde9, 0x150);
        _setUpActor(USER3);
        Target.receiveAllowance(
            29882650456281084738190043830201979887566836706330072603560922513535419521132, 228, 255, 204
        );
        _setUpActor(USER3);
        Target.accrueInterestForBothSilos();
        _delay(0x1cae0, 0xea4d);
        _setUpActor(USER1);
        Target.repayShares(16101437172150, 160, 115);
        _delay(0x6d464, 0x87a0);
        _setUpActor(USER3);
        Target.liquidationCall(
            110342258604813883136076491391080051692563040975227526460641868343995084633246,
            false,
            RandomGenerator(12, 255, 255)
        );
        _delay(0x74d9f, 0xb2fb);
        _setUpActor(USER1);
        Target.mint(28649857434211785716785075571150725017899301465750003284002157044320271768204, 59, 38, 254);
        _delay(0x7fff, 0x1740);
        _setUpActor(USER1);
        Target.repayShares(40227007729515353305131792903016741757545541658561409724602745097644628067887, 193, 27);
        _setUpActor(USER1);
        Target.MAX_PRICE();
        _delay(0x4daf5, 0x95ce);
        _setUpActor(USER1);
        Target.assert_BORROWING_HSPOST_D(9, 52);
        _delay(0xb3d0, 0xd13a);
        _setUpActor(USER1);
        Target.setOraclePrice(95081893068143359407883104546296025957664557752771364132166348654363223148495, 56);
        _setUpActor(USER2);
        Target.liquidationCallByDefaulting(
            76597552767090721918719815898960607117313991696237260016271266784287660272610,
            RandomGenerator(87, 179, 255)
        );
        _delay(0x465f9, 0xe4d);
        _setUpActor(USER1);
        Target.accrueInterestForBothSilos();
        _delay(0x7f7c2, 0xff);
        _setUpActor(USER1);
        Target.repay(78966050191243933347809934187510071778071286663533963193155543808380542453169, 76, 24);
        _delay(0x103ef, 0x107f);
        _setUpActor(USER1);
        Target.liquidationCallByDefaulting(
            16489003572533579321288095827535375950896583741864498533863095314641203887237,
            RandomGenerator(255, 240, 255)
        );
        _setUpActor(USER1);
        Target.repay(60330835776423846165004771220335477365446027906003784432952490792006788440388, 34, 241);
        _delay(0x8f9df, 0xd74);
        _setUpActor(USER1);
        Target.assert_BORROWING_HSPOST_D(220, 255);
        _setUpActor(USER1);
        Target.deposit(1524785992, 45, 192, 255);
        _delay(0x17e5e, 0x19c7);
        _setUpActor(USER2);
        Target.assertBORROWING_HSPOST_F(255, 137);
        _delay(0x1051, 0x7d93);
        _setUpActor(USER1);
        Target.increaseReceiveAllowance(
            44759756519204634339026046377163806977440747834421072263283382078182863713683, 172, 111
        );
        _delay(0x76ea6, 0x9cf);
        _setUpActor(USER1);
        Target.setOraclePrice(115792089237316195423570985008687907853269984665640564039457584007913129639934, 161);
        _delay(0x5f467, 0x89b0);
        _setUpActor(USER1);
        Target.borrow(1524785993, 187, 122);
        _delay(0x62123, 0x48c);
        _setUpActor(USER3);
        Target.assert_LENDING_INVARIANT_B(255, 36);
        _delay(0x2abe, 0x753b);
        _setUpActor(USER1);
        Target.redeem(46883910020419056406215527304463721007585229716096748624627748173239226962111, 0, 255, 1);
        _setUpActor(USER1);
        Target.assert_BORROWING_HSPOST_D(252, 255);
        _delay(0x3e1ce, 0xcfae);
        _setUpActor(USER1);
        Target.mint(8833740862598790822298872322557078511982463963928588332032819512705882315246, 247, 118, 255);
        _delay(0x6b721, 0xe59f);
        _setUpActor(USER1);
        Target.assertBORROWING_HSPOST_F(255, 255);
        _delay(0x6123, 0x320);
        _setUpActor(USER1);
        Target.setReceiveApproval(
            42433951474074729361621982518820040054100203943647270879125385874743773798748, 130, 24
        );
        _delay(0x582b0, 0x110c);
        _setUpActor(USER1);
        Target.approve(82109049031960918442738176079186229578228170818505220915176958281990161257318, 255, 255);
        _setUpActor(USER3);
        Target.increaseReceiveAllowance(24, 1, 124);
        _setUpActor(USER1);
        Target.repayShares(0, 181, 255);
        _setUpActor(USER1);
        Target.assert_SILO_HSPOST_D(255);
        _delay(0x214c8, 0xcfae);
        _setUpActor(USER1);
        Target.accrueInterestForBothSilos();
        _delay(0x329b9, 0x320);
        _setUpActor(USER1);
        Target.borrow(3167194, 15, 27);
        _delay(0x1b73c, 0x13c);
        _setUpActor(USER1);
        Target.liquidationCallByDefaulting(565, RandomGenerator(61, 14, 255));
        _delay(0x5408b, 0x26ee);
        _setUpActor(USER3);
        Target.receiveAllowance(1524785992, 224, 255, 22);
        _setUpActor(USER1);
        Target.increaseReceiveAllowance(
            61337461536744140313660380324818011942477261825176834788369124471526107825961, 255, 255
        );
        _setUpActor(USER3);
        Target.receiveAllowance(1524785991, 151, 255, 239);
        _setUpActor(USER3);
        Target.MAX_PRICE();
        _delay(0x4eb46, 0x8980);
        _setUpActor(USER3);
        Target.liquidationCall(1072546904, false, RandomGenerator(3, 231, 255));
        _delay(0x42655, 0xd619);
        _setUpActor(USER1);
        Target.repayShares(7820336472698723259836837139630046202385603710161591492277320897963474743784, 29, 255);
        _setUpActor(USER1);
        Target.assertBORROWING_HSPOST_F(140, 0);
        _delay(0x52e28, 0xd619);
        _setUpActor(USER1);
        Target.setReceiveApproval(416, 128, 33);
        _delay(0x1ae49, 0x5c65);
        _setUpActor(USER1);
        Target.assert_LENDING_INVARIANT_B(255, 156);
        _setUpActor(USER1);
        Target.approve(62210178003067872032363862593697997573465648818003862600306593549124497195450, 80, 135);
        _delay(0x46b47, 0x8ffb);
        _setUpActor(USER1);
        Target.accrueInterestForSilo(13);
        _delay(0x81f7, 0x1a41);
        _setUpActor(USER3);
        Target.assert_BORROWING_HSPOST_D(34, 255);
        _setUpActor(USER1);
        Target.liquidationCall(4370001, false, RandomGenerator(149, 21, 118));
        _delay(0x7b6a, 0x9d0);
        _setUpActor(USER3);
        Target.redeem(4370000, 255, 5, 135);
        _delay(0x7d1b7, 0x755a);
        _setUpActor(USER1);
        Target.borrow(65585194715669205132739287491084670852465903559164611781706710043332307970603, 27, 81);
        _delay(0x576ad, 0xdefe);
        _setUpActor(USER3);
        Target.receiveAllowance(262117389025040960656941050858116432210996162521186349, 247, 255, 24);
        _setUpActor(USER1);
        Target.decreaseReceiveAllowance(
            1771386858807101536288514066999049013603348058744995599677531409750372220582, 0, 4
        );
        _delay(0x3a4df, 0x1279);
        _setUpActor(USER1);
        Target.setReceiveApproval(
            38619747731699152230644537703097785233519251829562314810378839206026474715870, 134, 255
        );
        _delay(0xa41d, 0x8e0);
        _setUpActor(USER1);
        Target.mint(0, 255, 202, 255);
        _delay(0x1061d, 0x1bf2);
        _setUpActor(USER1);
        Target.transferFrom(4370001, 172, 255, 3);
        _delay(0xff, 0x279e);
        _setUpActor(USER2);
        Target.borrow(115792089237316195423570985008687907853269984665640564039457584007913129639932, 255, 41);
        _delay(0x214c8, 0xd8f2);
        _setUpActor(USER1);
        Target.liquidationCallByDefaulting(
            19440281052238228046917137526546382794030784465697728187592931051976865117079, RandomGenerator(43, 255, 0)
        );
        _delay(0x28928, 0xc107);
        _setUpActor(USER3);
        Target.assert_BORROWING_HSPOST_D(8, 91);
        _delay(0x307c6, 0x5b6b);
        _setUpActor(USER1);
        Target.repay(4370001, 204, 72);
        _delay(0x77bce, 0x5aeb);
        _setUpActor(USER1);
        Target.assertBORROWING_HSPOST_F(255, 169);
        _delay(0x1f113, 0x3c08);
        _setUpActor(USER1);
        Target.transfer(3054673, 16, 255);
        _delay(0x229b, 0x2c55);
        _setUpActor(USER1);
        Target.accrueInterestForSilo(181);
        _delay(0x142ef, 0xa475);
        _setUpActor(USER1);
        Target.borrowShares(0, 255, 255);
        _delay(0x50a, 0xa4f5);
        _setUpActor(USER1);
        Target.transitionCollateral(471, RandomGenerator(110, 42, 46));
        _delay(0x5bd20, 0x2e32);
        _setUpActor(USER1);
        Target.increaseReceiveAllowance(575959440, 62, 255);
        _delay(0x62e05, 0x5c65);
        _setUpActor(USER1);
        Target.transfer(4746397896427693764848337456381528962968105200219304006196744495775484463051, 53, 201);
        _delay(0x7d1b7, 0x26c0);
        _setUpActor(USER1);
        Target.accrueInterest(20);
        _setUpActor(USER1);
        Target.mint(1524785992, 108, 255, 255);
        _setUpActor(USER1);
        Target.mint(1524785992, 47, 255, 189);
        _delay(0x270c6, 0xa20);
        _setUpActor(USER1);
        Target.accrueInterestForSilo(37);
        _delay(0x2da39, 0x5515);
        _setUpActor(USER1);
        Target.assertBORROWING_HSPOST_F(255, 255);
        _delay(0x46b47, 0x1320);
        _setUpActor(USER1);
        Target.MAX_PRICE();
        _setUpActor(USER1);
        Target.liquidationCallByDefaulting(1524785993, RandomGenerator(125, 252, 255));
        _delay(0x7f467, 0x3b9a);
        _setUpActor(USER1);
        Target.repay(949854347, 81, 59);
        _delay(0x1c18d, 0xcdb9);
        _setUpActor(USER3);
        Target.repay(4369999, 255, 255);
        _setUpActor(USER1);
        Target.liquidationCall(
            106723709733403423642092629950696877456986098004742726315960636427595273783252,
            true,
            RandomGenerator(156, 255, 195)
        );
        _delay(0x142f0, 0x2be);
        _setUpActor(USER3);
        Target.liquidationCallByDefaulting(
            7152303565190857534109319837980237879270574259411664464502407147243597043254,
            RandomGenerator(157, 255, 138)
        );
        _delay(0x1021d, 0x7630);
        _setUpActor(USER3);
        Target.liquidationCallByDefaulting(
            66505786955507820238401180420926220756841145654195074064083144180067794290705,
            RandomGenerator(255, 255, 83)
        );
        _setUpActor(USER1);
        Target.borrowShares(1524785991, 29, 255);
        _setUpActor(USER1);
        Target.borrowShares(940155, 198, 153);
        _setUpActor(USER1);
        Target.MAX_PRICE();
        _setUpActor(USER1);
        Target.mint(1524785991, 187, 36, 6);
        _delay(0x4a9a4, 0x6c9c);
        _setUpActor(USER1);
        Target.receiveAllowance(
            88968095358741298776878563895436183321799220856386626409567278712462649867910, 255, 212, 255
        );
        _setUpActor(USER1);
        Target.accrueInterestForSilo(247);
        _delay(0x307c6, 0x5ef7);
        _setUpActor(USER1);
        Target.accrueInterestForBothSilos();
        _setUpActor(USER3);
        Target.mint(1524785991, 24, 21, 194);
        _delay(0x8f9df, 0x5daa);
        _setUpActor(USER1);
        Target.mint(1524785991, 154, 16, 68);
        _setUpActor(USER1);
        Target.transitionCollateral(
            21409319520113706690308350931635367003876811136146692412440777169173698490652,
            RandomGenerator(255, 255, 176)
        );
        _delay(0x2621e, 0xb31c);
        _setUpActor(USER1);
        Target.setReceiveApproval(
            77337307715719400453942886950771053198709764232338099106449501237073269072113, 255, 207
        );
        _delay(0x93a, 0xe8a0);
        _setUpActor(USER1);
        Target.MAX_PRICE();
        _delay(0x74813, 0xdfb9);
        _setUpActor(USER1);
        Target.repay(4369999, 255, 255);
        _delay(0x142ee, 0x3c08);
        _setUpActor(USER1);
        Target.transferFrom(
            10193277817637005360558734678678705754054357859575678243450813619098131614745, 12, 244, 255
        );
        _delay(0x52be8, 0x3032);
        _setUpActor(USER1);
        Target.setOraclePrice(1524785992, 70);
        _delay(0x11d50, 0xea4d);
        _setUpActor(USER1);
        Target.repayShares(1282456444, 254, 255);
        _delay(0x6b721, 0x1320);
        _setUpActor(USER1);
        Target.deposit(37294160861839470945715928029075211652654478420596236659019067592348287092651, 36, 35, 255);
        _delay(0x329b9, 0x116e);
        _setUpActor(USER1);
        Target.receiveAllowance(485, 255, 14, 255);
        _setUpActor(USER3);
        Target.liquidationCallByDefaulting(
            62642639977860731642902822164935719331006320956980023718404314800998625436649,
            RandomGenerator(62, 255, 253)
        );
        _setUpActor(USER1);
        Target.assert_BORROWING_HSPOST_D(255, 163);
        _setUpActor(USER3);
        Target.approve(1524785991, 128, 76);
        _delay(0x4694f, 0xc85a);
        _setUpActor(USER1);
        Target.accrueInterest(22);
        _setUpActor(USER2);
        Target.approve(20675247123038912832082479094560636220586328266629270150565070213739901167551, 131, 1);
        _delay(0x4694f, 0x95ce);
        _setUpActor(USER1);
        Target.liquidationCallByDefaulting(
            72142487059008203792313838954728895985149319951503394542868515209319545467410,
            RandomGenerator(231, 99, 179)
        );
        _delay(0x3d159, 0x13bd);
        _setUpActor(USER1);
        Target.accrueInterestForSilo(220);
        _delay(0x2328, 0x30cd);
        _setUpActor(USER1);
        Target.transitionCollateral(
            93914473734006709915291049324092360852395729332520836303880750983378701712, RandomGenerator(255, 0, 25)
        );
        _delay(0x307c6, 0x2e32);
        _setUpActor(USER1);
        Target.transitionCollateral(
            115792089237316195423570985008687907853269984665640564039457584007913129639935,
            RandomGenerator(255, 115, 206)
        );
        _setUpActor(USER3);
        Target.borrowShares(1524785992, 255, 128);
        _delay(0x307c6, 0x3c09);
        _setUpActor(USER1);
        Target.MAX_PRICE();
        _setUpActor(USER1);
        Target.transfer(4676460, 15, 91);
        _delay(0xff, 0x9cf);
        _setUpActor(USER1);
        Target.MAX_PRICE();
        _delay(0x2a045, 0x9cf);
        _setUpActor(USER1);
        Target.MAX_PRICE();
        _delay(0x576ad, 0x73);
        _setUpActor(USER1);
        Target.transferFrom(
            90318476213917949728386927160082259735316458568522904138088398235816897711407, 255, 255, 125
        );
        _delay(0x76ea6, 0x87a0);
        _setUpActor(USER1);
        Target.increaseReceiveAllowance(4369999, 99, 255);
        _delay(0x85b27, 0x94d4);
        _setUpActor(USER1);
        Target.borrow(74688935994650140316301830625940596670416427805434521210507053356400113373815, 3, 49);
        _delay(0x11d50, 0x2ea6);
        _setUpActor(USER1);
        Target.transferFrom(
            110083703931358221363076659603373759752367532300390439908929586863011616324167, 5, 134, 255
        );
        _delay(0x3256a, 0x8980);
        _setUpActor(USER1);
        Target.assert_BORROWING_HSPOST_D(143, 15);
        _delay(0x1225, 0x755a);
        _setUpActor(USER1);
        Target.transitionCollateral(
            9185236013203816443548148432183170538667391471045253198729267642083338298609,
            RandomGenerator(255, 255, 229)
        );
        _setUpActor(USER1);
        Target.assert_LENDING_INVARIANT_B(20, 192);
        _setUpActor(USER1);
        Target.liquidationCallByDefaulting(
            83827132201277929604310278461769535334031346570138975986843818449008384355583,
            RandomGenerator(23, 255, 67)
        );
        _delay(0x4b4fe, 0x1c9b);
        _setUpActor(USER1);
        Target.accrueInterest(32);
        _delay(0x3340a, 0x89b0);
        _setUpActor(USER1);
        Target.liquidationCall(
            115792089237316195423570985008687907853269984665640564039457584007913129639935,
            false,
            RandomGenerator(255, 63, 61)
        );
        _delay(0x712e4, 0x9d0);
        _setUpActor(USER1);
        Target.liquidationCallByDefaulting(
            39149888895239045621541183838454641162507772666153361283499610244049868432182,
            RandomGenerator(225, 40, 64)
        );
        _setUpActor(USER1);
        Target.transitionCollateral(
            5118569183195425567126660190276278917075707430839223737981446780898544030189,
            RandomGenerator(111, 255, 42)
        );
        _delay(0x75d98, 0x769a);
        _setUpActor(USER3);
        Target.borrowShares(212831, 68, 122);
        _delay(0x80772, 0xa4f5);
        _setUpActor(USER3);
        Target.receiveAllowance(
            15034577099901710996919593284599078084840332859386219662641994623747670967148, 112, 227, 11
        );
        _setUpActor(USER3);
        Target.MIN_PRICE();
        _delay(0xb056, 0x13bd);
        _setUpActor(USER1);
        Target.receiveAllowance(
            45850619002861701817056430916337683895700250925567096412401997802148956417440, 84, 236, 13
        );
        _delay(0x5eb90, 0x13be);
        _setUpActor(USER2);
        Target.transferFrom(90508370297569908360089741359687802433805485817034804351043343463550528335829, 34, 12, 70);
        _delay(0x94ab, 0x3032);
        _setUpActor(USER1);
        Target.assertBORROWING_HSPOST_F(255, 255);
        _setUpActor(USER1);
        Target.MAX_PRICE();
        _setUpActor(USER3);
        Target.liquidationCall(
            52143517035722306241620094494644035298324747384704421554497690072878146922462,
            true,
            RandomGenerator(230, 255, 255)
        );
        _delay(0x620d, 0x3c07);
        _setUpActor(USER1);
        Target.decreaseReceiveAllowance(4370001, 9, 255);
        _delay(0x12972, 0x41ff);
        _setUpActor(USER1);
        Target.assert_BORROWING_HSPOST_D(193, 112);
        _delay(0x28928, 0xeb6b);
        _setUpActor(USER1);
        Target.accrueInterestForBothSilos();
        _setUpActor(USER3);
        Target.borrow(95712136588299355648674910592899302043562829991942056757117289105891532633412, 115, 255);
        _setUpActor(USER1);
        Target.withdraw(14193260291434410611068827059854249129803974441164710922226248989727731303664, 0, 171, 98);
        _delay(0x48a23, 0x1c9b);
        _setUpActor(USER1);
        Target.accrueInterest(255);
        _delay(0x46b47, 0xd0cb);
        _setUpActor(USER1);
        Target.borrowShares(3384161, 128, 170);
        _delay(0x41607, 0xe8a0);
        _setUpActor(USER1);
        Target.increaseReceiveAllowance(360616853392099, 2, 0);
        _delay(0x668ee, 0x1075);
        _setUpActor(USER1);
        Target.assert_LENDING_INVARIANT_B(171, 255);
    }

    function _setUpActor(address actor) internal {
        vm.startPrank(actor);
        // Add any additional actor setup here if needed
    }

    function _delay(uint256 timeInSeconds, uint256 numBlocks) internal {
        vm.warp(block.timestamp + timeInSeconds);
        vm.roll(block.number + numBlocks);
    }

    function _defaultHooksBefore(address silo) internal override(BaseHandlerDefaulting, DefaultBeforeAfterHooks) {
        BaseHandlerDefaulting._defaultHooksBefore(silo);
    }
}
