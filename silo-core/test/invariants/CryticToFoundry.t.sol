// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries
import "forge-std/Test.sol";
import "forge-std/console.sol";

// Contracts
import {Invariants} from "./Invariants.t.sol";
import {Setup} from "./Setup.t.sol";
import {ISiloConfig} from "silo-core/contracts/SiloConfig.sol";
import {MockSiloOracle} from "./utils/mocks/MockSiloOracle.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

/*
 * Test suite that converts from  "fuzz tests" to foundry "unit tests"
 * The objective is to go from random values to hardcoded values that can be analyzed more easily
 */
contract CryticToFoundry is Invariants, Setup {
    CryticToFoundry Tester = this;
    uint256 constant DEFAULT_TIMESTAMP = 337812;

    modifier setup() override {
        targetActor = address(actor);
        _;
        targetActor = address(0);
    }

    function setUp() public {
        // Deploy protocol contracts
        _setUp();

        // Deploy actors
        _setUpActors();

        // Initialize handler contracts
        _setUpHandlers();

        /// @dev fixes the actor to the first user
        actor = actors[USER1];

        vm.warp(DEFAULT_TIMESTAMP);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                 FAILING INVARIANTS REPLAY                                 //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                              FAILING POSTCONDITIONS REPLAY                                //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function test_replay_assert_BORROWING_HSPOST_F() public {
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(193410);
        Tester.mint(2417851639229258349412351, 9, 212, 221);
        _delay(14);
        Tester.deposit(100000000000000000000000000000001, 118, 6, 4);
        Tester.mint(2417851639229258349412351, 9, 212, 225);
        _delay(512439);
        Tester.deposit(69444444444443, 8, 119, 239);
        _setUpActor(0x0000000000000000000000000000000000020000);
        _delay(510590);
        Tester.deposit(499999999999999999, 57, 2, 13);
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(322274);
        Tester.setOraclePrice(85325694741497293970114900540325703882142136582466790768881058534661869607342, 174);
        _setUpActor(0x0000000000000000000000000000000000020000);
        _delay(24867);
        Tester.setOraclePrice(43207562170869945412787795144717286439709176267592715576009429839015455091837, 113);
        _delay(55);
        Tester.assertBORROWING_HSPOST_F(56, 215);
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(390717);
        Tester.transferFrom(2897676309, 29, 40, 12);
        _delay(126793);
        _delay(499805);
        Tester.borrowShares(50228011671950330309169572203707085386011832257117795315954720092389856076046, 1, 20);
        _delay(568303);
        Tester.redeem(44941986255502561297318478138867417946571817659141510774328760729431238239191, 10, 63, 11);
        _delay(537598);
        Tester.setReceiveApproval(
            54240591665615479792438906247194233447669730656649631639278775344414187956629, 130, 38
        );
        _setUpActor(0x0000000000000000000000000000000000020000);
        _delay(370487);
        Tester.approve(58683455561554494632124242960254730942971379018831365076494610077263994922018, 48, 34);
        _delay(3867);
        _delay(537687);
        Tester.borrow(4422950546145201694882358831063848405430339188834070564158780592703015551971, 4, 40);
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(389576);
        Tester.borrowShares(3744612559021541957160054071969076782, 0, 145);
        _delay(370488);
        _delay(114541);
        Tester.borrowSameAsset(9427610262719372917047848554186210596955247207389145729765261707856625335925, 3, 82);
        _setUpActor(0x0000000000000000000000000000000000020000);
        _delay(436727);
        Tester.increaseReceiveAllowance(68, 60, 108);
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(91011);
        Tester.redeem(828288516, 64, 28, 89);
        _delay(240693);
        Tester.setOraclePrice(52915718629196049451388510361446452516620029081340442233617707039992909407707, 152);
        _delay(452190);
        Tester.borrowSameAsset(237, 180, 8);
        _delay(95198);
        Tester.switchCollateralToThisSilo(45);
        _setUpActor(0x0000000000000000000000000000000000020000);
        _delay(18);
        Tester.withdraw(38133102091987032070981629283273601378239912397744651828825688961937124872721, 66, 119, 243);
        _delay(419558);
        _setUpActor(0x0000000000000000000000000000000000010000);
        Tester.accrueInterestForSilo(225);
        _delay(303440);
        Tester.repay(115792089237316195423570985008687907853269984665640564039457584007913129639933, 147, 138);
        _delay(20);
        Tester.decreaseReceiveAllowance(
            42271708428702437162045281838654932472332677825614504426711854969248495003551, 0, 29
        );
        _delay(209930);
        Tester.borrow(24435290935346342347589214797042234990314080549446825362120725011266203001993, 85, 7);
        _delay(568302);
        Tester.repayShares(115792089237316195423570985008687907853269984665640564039457584007913129639931, 218, 116);
        Tester.mint(52169554911342614736952778091147, 0, 4, 158);
        _delay(350071);
        Tester.mint(95070932812866402748192169330481, 2, 89, 21);
        Tester.assertBORROWING_HSPOST_F(3, 9);
    }

    function test_replay_transitionCollateral() public {
        //@audit-issue
        _setUpActor(0x0000000000000000000000000000000000010000);
        Tester.mint(1197289752, 0, 0, 1);
        Tester.borrowSameAsset(666462, 0, 0);
        _delay(8);
        Tester.liquidationCall(
            92376606079425577106588961289845324639688828464328356647373507302383077493937,
            false,
            RandomGenerator(34, 37, 29)
        );
        _setUpActor(0x0000000000000000000000000000000000020000);
        _delay(537688);
        Tester.switchCollateralToThisSilo(119);
        _delay(2);
        _delay(303757);
        Tester.accrueInterest(6);
        _delay(322310);
        Tester.withdraw(115792089237316195423570985008687907853269984665640564039457584007913129639931, 1, 119, 160);
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(434894);
        Tester.repay(136, 5, 21);
        _setUpActor(0x0000000000000000000000000000000000020000);
        _delay(195123);
        Tester.borrowSameAsset(102750900109441762338823263821223164621313590537445587886855167060081089416903, 87, 135);
        _delay(427371);
        Tester.accrueInterest(178);
        _setUpActor(0x0000000000000000000000000000000000030000);
        _delay(424755);
        Tester.increaseReceiveAllowance(63, 31, 49);
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(322256);
        Tester.repayShares(34, 30, 251);
        _setUpActor(0x0000000000000000000000000000000000020000);
        _delay(322286);
        Tester.accrueInterestForBothSilos();
        _delay(466841);
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(190836);
        Tester.receiveAllowance(
            67879026546791232335401397295928718266148622969132955181092061957730287594974, 141, 146, 54
        );
        _setUpActor(0x0000000000000000000000000000000000030000);
        _delay(10674);
        Tester.assert_BORROWING_HSPOST_D(253, 85);
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(306997);
        Tester.borrowSameAsset(21585613697354954902898453804133624968432917054401443086730666018432324372553, 1, 27);
        _setUpActor(0x0000000000000000000000000000000000020000);
        _delay(22080);
        Tester.mint(93646602918060477136800477714624610914049052709935395894375273044702306602463, 91, 160, 4);
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(519847);
        Tester.deposit(9624075175388396098104258216271404880752482209615601192127206862564779763991, 67, 16, 136);
        _setUpActor(0x0000000000000000000000000000000000020000);
        _delay(36);
        Tester.approve(115792089237316195423570985008687907853269984665640564039457434007913129639937, 160, 163);
        _setUpActor(0x0000000000000000000000000000000000030000);
        _delay(190836);
        Tester.deposit(850000000000000001, 91, 190, 12);
        _delay(414579);
        Tester.receiveAllowance(999999999999999999, 1, 162, 253);
        _delay(588255);
        Tester.assertBORROWING_HSPOST_F(164, 35);
        _setUpActor(0x0000000000000000000000000000000000020000);
        _delay(243805);
        Tester.setOraclePrice(63175501356154510779854281709278062873128985787959537881584842995235862408423, 229);
        _delay(3867);
        Tester.mint(83027090415153426737556317870318965479485907605649508132829330970971093388044, 46, 131, 197);
        _delay(537688);
        Tester.deposit(115792089237316195423570985008687907853269984665640564039457584007911596747873, 48, 146, 13);
        _delay(3865);
        _delay(332369);
        Tester.redeem(115696897690052895286399291642729438185136418481807235877070495890283110725393, 0, 68, 86);
        _setUpActor(0x0000000000000000000000000000000000030000);
        _delay(385873);
        Tester.setOraclePrice(83384416244348501179099460970931716627069069609758431118822185425433146818470, 56);
        _delay(405856);
        _delay(64407);
        Tester.flashLoan(789, 1000000000000000000000000000000, 87, 141);
        _delay(428920);
        Tester.mint(115792089237316195423570985008687907853269984665640564039457559007913129639935, 202, 40, 19);
        _delay(159);
        Tester.setDaoFee(99, 9999999999);
        _setUpActor(0x0000000000000000000000000000000000020000);
        _delay(150736);
        Tester.accrueInterestForBothSilos();
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(82672);
        Tester.repay(61270666630293674668380796705131752310548198689411997177078758471100742839675, 226, 201);
        _setUpActor(0x0000000000000000000000000000000000030000);
        _delay(251325);
        Tester.decreaseReceiveAllowance(
            115792089237316195423570985008687907853269984665640564039457584007913129639929, 161, 241
        );
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(2);
        Tester.increaseReceiveAllowance(2835717307, 242, 54);
        _delay(600848);
        Tester.redeem(115792089237316195423570985008687907852929702298719196538670242665374803829242, 63, 21, 8);
        _setUpActor(0x0000000000000000000000000000000000020000);
        _delay(295513);
        Tester.borrowSameAsset(48064507900596314567628153981727950698207055150846498568362492192054574943706, 57, 11);
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(295513);
        Tester.mint(1645187383, 65, 203, 64);
        _setUpActor(0x0000000000000000000000000000000000020000);
        _delay(52934);
        Tester.accrueInterest(32);
        _setUpActor(0x0000000000000000000000000000000000030000);
        _delay(89);
        Tester.approve(63736002375795722402532023601167000453146129629797850313132499043700200495369, 0, 160);
        _delay(257969);
        Tester.repay(887008753, 18, 219);
        _delay(169263);
        Tester.accrueInterestForSilo(203);
        _delay(195582);
        Tester.transfer(10305733602818994360878499694173399856229685277777434977694285471670450949993, 61, 255);
        _delay(49781);
        _setUpActor(0x0000000000000000000000000000000000020000);
        _delay(498257);
        Tester.withdraw(115792089237316195423570985008687907853269984665640564039457584007913129639931, 151, 253, 9);
        _delay(175570);
        Tester.accrueInterestForBothSilos();
        _delay(415881);
        Tester.mint(115792089237316195423570985008687907853269984665640564039457559007913129639935, 202, 40, 28);
        _delay(175569);
        Tester.decreaseReceiveAllowance(
            86033374192268632842155156008275118788430627337550318165948572826243408976079, 89, 120
        );
        _delay(190836);
        Tester.repay(66814415143154679173915046722655439075120825244378316994010404351618995951169, 54, 57);
        _delay(314384);
        _setUpActor(0x0000000000000000000000000000000000030000);
        _delay(474987);
        Tester.receiveAllowance(
            50795184966779784027603036522320549979505304570834191087533964097607569954327, 50, 234, 16
        );
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(326328);
        Tester.liquidationCall(39983289040657910432720271928938050518363, true, RandomGenerator(32, 86, 68));
        _delay(150737);
        Tester.receiveAllowance(
            78751624497308038607439927082797635216803971294347223466850498631676761763090, 145, 10, 65
        );
        _delay(762853);
        _delay(578493);
        Tester.switchCollateralToThisSilo(115);
        _setUpActor(0x0000000000000000000000000000000000030000);
        _delay(297507);
        Tester.redeem(103292542714901428212749899392399784293332632033598272698868677540937841349969, 156, 137, 55);
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(322327);
        Tester.assert_SILO_HSPOST_D(12);
        _setUpActor(0x0000000000000000000000000000000000020000);
        _delay(322309);
        Tester.decreaseReceiveAllowance(
            115792089237316195423570985008687907853269984665640564039457584007913129639933, 52, 32
        );
        _delay(466841);
        Tester.borrow(111857468998492536781144493436727280058541974475885968952276151962020287221554, 35, 38);
        _delay(7993);
        Tester.approve(4204136582279055683284325446937663413913789881274168253584260281692362676021, 9, 8);
        _delay(30);
        Tester.accrueInterestForBothSilos();
        _delay(389577);
        Tester.receiveAllowance(
            80824454834511420687758967569877893054007441392552707767302417748861012136828, 35, 89, 175
        );
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(322274);
        Tester.borrowSameAsset(20147076027434589744787435822140337909775978096308948447385191221415469831626, 201, 225);
        _delay(322291);
        Tester.assertBORROWING_HSPOST_F(49, 10);
        _delay(215940);
        Tester.accrueInterestForBothSilos();
        _setUpActor(0x0000000000000000000000000000000000020000);
        _delay(322255);
        Tester.transfer(115792089237316195423570985008687907852865318453788217445206590704255894163987, 67, 202);
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(54939);
        Tester.deposit(300000000000000000, 136, 169, 48);
        _delay(2591);
        _setUpActor(0x0000000000000000000000000000000000030000);
        _delay(34);
        Tester.switchCollateralToThisSilo(41);
        _delay(54939);
        _setUpActor(0x0000000000000000000000000000000000020000);
        _delay(452492);
        Tester.borrowSameAsset(2547025546513014238365418645791225841947781966568527851471940416871239751876, 49, 93);
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(135879);
        Tester.accrueInterest(212);
        _setUpActor(0x0000000000000000000000000000000000030000);
        _delay(442677);
        Tester.assert_BORROWING_HSPOST_D(23, 36);
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(2);
        Tester.accrueInterestForSilo(64);
        _setUpActor(0x0000000000000000000000000000000000020000);
        _delay(314382);
        Tester.transfer(115792089237316195423570985008687907852865318453788217445206590704255894163987, 67, 202);
        _delay(322347);
        Tester.transfer(115792089237316195423570985008687907852865318453788217445206590704255894163987, 67, 202);
        _delay(390247);
        Tester.assert_BORROWING_HSPOST_D(101, 19);
        _setUpActor(0x0000000000000000000000000000000000030000);
        _delay(526880);
        Tester.borrowSameAsset(24900104684468280764509599872421672333601370005009598846076454071969943549876, 63, 175);
        _delay(190836);
        Tester.mint(115792089237316195423570985008687907853269984665640564039457559007913129639935, 202, 40, 19);
        _delay(490703);
        _setUpActor(0x0000000000000000000000000000000000020000);
        _delay(185532);
        Tester.transitionCollateral(1524785992, 7, 136, 158);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                     INVARIANTS REPLAY                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function test_replayechidna_BASE_INVARIANT() public {
        Tester.setOraclePrice(154174253363420274135519693994558375770505353341038094319633, 1);
        Tester.setOraclePrice(117361312846819359113791019924540616345894207664659799350103, 0);
        Tester.mint(1025, 0, 1, 0);
        Tester.deposit(1, 0, 0, 1);
        Tester.borrowShares(1, 0, 0);
        echidna_BASE_INVARIANT();
        Tester.setOraclePrice(1, 1);
        echidna_BASE_INVARIANT();
    }

    // FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_replayechidna_LENDING_INVARIANT
    function test_replayechidna_LENDING_INVARIANT() public {
        Tester.deposit(1, 0, 0, 1);
        echidna_LENDING_INVARIANT();
    }

    function test_replayechidna_BORROWING_INVARIANT2() public {
        Tester.mint(1, 0, 0, 1);
        Tester.deposit(1, 0, 0, 1);
        Tester.assert_LENDING_INVARIANT_B(0, 1);
        echidna_BORROWING_INVARIANT();
    }

    function test_replayechidna_BASE_INVARIANT2() public {
        Tester.mint(1, 0, 1, 1);
        Tester.deposit(1, 0, 1, 1);
        Tester.assert_LENDING_INVARIANT_B(1, 1);
        echidna_BASE_INVARIANT();
    }

    function test_echidna_BASE_INVARIANT2() public {
        this.borrowShares(30200315428657041181692818570648842165065568767143529577951521503506330530609, 0, 62);
        _delay(297507);
        this.borrow(24676309369365446429188617450178, 153, 172);
        _delay(18525);
        this.increaseReceiveAllowance(
            99660895124953974644233210972242386669999403047765480327126411789742549576368, 181, 91
        );
        _delay(141692);
        this.repay(101372206747301271834761305009245902947872462179580934218127627924045863531744, 9, 159);
        _delay(367974);
        this.borrowShares(8032312716394233662712281686181593822882968583701061059278525601052468728207, 218, 2);
        _delay(1167988 + 437307);
        this.increaseReceiveAllowance(371080552416919877990254144423618836769, 99, 5);
        _delay(390117);
        this.redeem(59905965166056961781632000159517596677870250320753863880326268500874116007290, 31, 0, 37);
        _delay(12433);
        this.borrowSameAsset(6827332602758654332354477904142168468488799183670823563697384434166987337716, 1, 5);
        _delay(324745 + 555411);
        this.accrueInterest(61);
        _delay(563776);
        this.borrowSameAsset(6761450672746141936113668479670284573524169850700252331526405092555618758321, 2, 10);
        _delay(385872 + 456951);
        this.setDaoFee(0, 2877132025);
        _delay(31082);
        this.repayShares(32472179111736603803505870944287, 4, 22);
        _delay(174548);
        this.receiveAllowance(91469683133036834644101184730609374679152313976056066054005700, 150, 17, 116);
        _delay(276464);
        this.decreaseReceiveAllowance(0, 5, 0);
        _delay(520753);
        this.setOraclePrice(151115727451828646838273, 23);
        _delay(58873);
        this.decreaseReceiveAllowance(424412765956835803999046, 41, 16);
        _delay(237655);
        this.repay(2716659549, 19, 123);
        _delay(50346);
        this.setOraclePrice(16157129571321233639644349780651112871298492558603692980126389590854127811494, 165);
        _delay(189582);
        this.withdraw(4164541715857873049718334791601233354128474156253387690275982252087686776267, 29, 29, 30);
        _delay(1168790 + 318278);
        this.accrueInterestForBothSilos();
        this.assert_BORROWING_HSPOST_D(0, 0);
        _delay(348683);
        this.assert_LENDING_INVARIANT_B(0, 21);
        echidna_BASE_INVARIANT();
    }

    function test_echidna_BORROWING_INVARIANT() public {
        _setUpActorAndDelay(USER2, 203047);
        this.setOraclePrice(75638385906155076883289831498661502101511673487426594778361149796941034811732, 64);
        _setUpActorAndDelay(USER1, 3032);
        this.deposit(77844067395127635960841998878023, 20, 55, 57);
        _setUpActorAndDelay(USER1, 86347);
        this.deposit(774, 25, 0, 211);
        _setUpActorAndDelay(USER2, 114541);
        this.assertBORROWING_HSPOST_F(211, 8);
        _setUpActorAndDelay(USER1, 487078);
        this.setOraclePrice(115792089237316195423570985008687907853269984665640562830531764393283954933761, 0);
        echidna_BORROWING_INVARIANT();
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   POSTCONDITIONS REPLAY                                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function test_withdrawEchidna() public {
        Tester.mint(261704911235117686095, 3, 22, 5);
        Tester.setOraclePrice(5733904121326457137913237185177414188002932016538715575300939815758706, 1);
        Tester.mint(315177161663537856181160994225, 0, 1, 3);
        Tester.borrowShares(1, 0, 0);
        Tester.setOraclePrice(5735839262457902375842327974553553747246352514262698977554375720302080, 0);
        Tester.withdraw(1238665, 0, 0, 1);
    }

    function test_depositEchidna() public {
        Tester.deposit(1, 0, 0, 0);
    }

    function test_flashLoanEchidna() public {
        Tester.flashLoan(1, 76996216303583, 0, 0);
    }

    function test_transitionCollateralEchidna() public {
        Tester.transitionCollateral(0, 0, 0, 0);
    }

    function test_liquidationCallEchidna() public {
        Tester.mint(10402685166958480039898380057, 0, 0, 1);
        Tester.deposit(1, 0, 1, 1);
        Tester.setOraclePrice(32922152482718336970808482575712338131227045040770117410308, 1);
        Tester.borrowShares(1, 0, 0);
        Tester.setOraclePrice(1, 1);
        Tester.liquidationCall(
            1179245955276247436741786656479833618730492640882500598892, false, RandomGenerator(0, 0, 1)
        );
    }

    function test_replayBorrowSameAsset() public {
        Tester.mint(146189612359507306544594, 0, 0, 1);
        Tester.borrowSameAsset(1, 0, 0);
        Tester.mint(2912, 0, 1, 0);
        Tester.setOraclePrice(259397900503974518365051033297974490300799102382829890910371, 1);
        Tester.switchCollateralToThisSilo(1);
        Tester.setOraclePrice(0, 1);
        Tester.borrowSameAsset(1, 0, 0);
    }

    function test_replayBorrowNotSolvent() public {
        Tester.mint(3757407288159739, 0, 0, 0);
        Tester.mint(90935896182375204709, 1, 0, 1);
        Tester.borrowSameAsset(1567226244662, 0, 0);
        Tester.assert_LENDING_INVARIANT_B(0, 0);
        Tester.setOraclePrice(0, 0);
        _delay(30);
        Tester.borrowShares(1, 0, 0);
    }

    function test_replaytransitionCollateral() public {
        Tester.mint(1023, 0, 0, 0);
        Tester.transitionCollateral(679, 0, 0, 0);
    }

    function test_replayredeem() public {
        // Mint on silo 0 protected collateral
        Tester.mint(1025, 0, 0, 0);
        Tester.setOraclePrice(282879448546642360938617676663071922922812, 0);

        // Mint on silo 1 collateral
        Tester.mint(36366106112624882, 0, 1, 1);

        // Borrow shares on silo 1 using silo 0 protected collateral as collateral
        Tester.borrowShares(315, 0, 1);

        // Switch collateral from 0 silo 1
        Tester.switchCollateralToThisSilo(1);

        // Max Withdraw from silo 1
        Tester.assert_LENDING_INVARIANT_B(1, 1);
        _delay(345519);
        Tester.redeem(694, 0, 0, 0);
    }

    function test_replaytransitionCollateral2() public {
        Tester.mint(4003, 0, 0, 0);
        Tester.mint(4142174, 0, 1, 1);
        Tester.setOraclePrice(5167899937944767889217962943343171205019348763, 0);
        Tester.assertBORROWING_HSPOST_F(0, 1);
        Tester.setOraclePrice(2070693789985146455311434266782705402030751026, 1);
        Tester.transitionCollateral(2194, 0, 0, 0);
    }

    function test_replayborrowShares2() public {
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(326792);
        Tester.mint(340282423155723237052512385577070742059, 30, 112, 137);
        _delay(474683);
        Tester.deposit(3121116753, 199, 132, 32);
        _setUpActor(0x0000000000000000000000000000000000020000);
        _delay(578494);
        Tester.borrowSameAsset(699, 159, 120);
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(306998);
        Tester.assert_LENDING_INVARIANT_B(28, 15);
        _setUpActor(0x0000000000000000000000000000000000020000);
        _delay(326329);
        Tester.assert_LENDING_INVARIANT_B(6, 30);
        _setUpActor(0x0000000000000000000000000000000000030000);
        _delay(267435);
        Tester.mint(23937089108029247970912786558, 27, 0, 13);
        _setUpActor(0x0000000000000000000000000000000000020000);
        _delay(33);
        Tester.deposit(25000000000000001, 190, 13, 254);
        _delay(22080);
        Tester.setOraclePrice(56466874253382507631663260754233357053746765190105168440061833491889481131123, 159);
        _delay(50246);
        Tester.borrowShares(31361538392562449977676, 255, 16);
    }

    function test_replayTesterassertBORROWING_HSPOST_F2() public {
        Tester.mint(40422285801235863700109, 1, 1, 0); // Deposit on Silo 1 for ACTOR2
        Tester.deposit(2, 0, 0, 1); // Deposit on Silo 0 for ACTOR1
        Tester.assertBORROWING_HSPOST_F(1, 0); // ACTOR tries to maxBorrow on Silo 0
    }

    function test_replayborrow2() public {
        // Deposit on Silo 0
        Tester.mint(1197289752, 0, 0, 1);

        // Borrow same asset on Silo 0
        Tester.borrowSameAsset(666462, 0, 0);

        // Deposit on Silo 1
        Tester.deposit(1, 0, 1, 0);

        // Max withdraw from Silo 0
        Tester.assert_LENDING_INVARIANT_B(0, 1);

        _delay(3889);

        // Borrow same asset on Silo 1
        // Lower price of Asset 0 to the minimum (not zero, the hander clamps the value to a minimum price)
        Tester.setOraclePrice(0, 0);

        // Borrow from Silo 0 using Silo 1 as collateral
        Tester.borrow(1, 0, 0);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                 POSTCONDITIONS: FINAL REVISION                            //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function test_replay_deposit() public {
        Tester.mint(13030923723425133684497, 0, 0, 0);
        Tester.deposit(21991861, 13, 59, 3);
        Tester.borrow(621040, 0, 1);
        _delay(11818);
        Tester.accrueInterestForBothSilos();
        _delay(3706);
        Tester.deposit(7866581, 0, 1, 1);
    }

    function test_replay_borrow() public {
        Tester.mint(2518531959823837031380, 0, 0, 0);
        Tester.deposit(1780157, 0, 1, 1);
        Tester.borrow(1722365, 0, 1);
        _delay(29);
        Tester.accrueInterestForBothSilos();
        _delay(22);
        Tester.borrow(1, 0, 1);
    }

    function test_replay_borrowSameAsset() public {
        Tester.mint(580836077360653463743629447964978, 0, 0, 0);
        Tester.setOraclePrice(39661949851364677948183886078802709693713432198988909772643851412, 1);
        Tester.mint(1054429549, 0, 1, 1);
        Tester.assertBORROWING_HSPOST_F(0, 1);
        _delay(1638);
        Tester.mint(27081962, 0, 1, 0);
        _delay(67);
        Tester.borrowSameAsset(1, 0, 1);
    }

    function test_replay_assert_BORROWING_HSPOST_D() public {
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(322357);
        Tester.mint(578648582, 16, 16, 54);
        _delay(4177);
        Tester.deposit(85084973744223259135554130, 3, 10, 101);
        _setUpActor(0x0000000000000000000000000000000000020000);
        _delay(475271);
        Tester.borrowSameAsset(1, 0, 0);
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(46521);
        Tester.assert_LENDING_INVARIANT_B(0, 1);
        _setUpActor(0x0000000000000000000000000000000000020000);
        _delay(187977);
        Tester.assert_BORROWING_HSPOST_D(90, 150);
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(411916);
        Tester.withdraw(115792089237316195423570985008687907853269984665640564039457584007910656676987, 104, 38, 135);
        _delay(62993);
        Tester.accrueInterest(42);
        _delay(490448);
        Tester.assert_BORROWING_HSPOST_D(1, 88);
    }

    function test_replay_assert_LENDING_INVARIANT_B() public {
        // error: NotSolvent
        Tester.mint(632707868, 0, 0, 1);
        Tester.borrowSameAsset(313517, 0, 0);
        _delay(195346);
        Tester.accrueInterest(0);
        _delay(130008);
        Tester.assert_LENDING_INVARIANT_B(0, 1);
    }

    function test_replay_assertBORROWING_HSPOST_F() public {
        Tester.mint(11638058238813243150339, 0, 0, 0);
        Tester.deposit(8533010, 0, 1, 1);
        Tester.borrow(8256930, 0, 1);
        _delay(12);
        Tester.accrueInterest(1);
        _delay(7);
        Tester.assertBORROWING_HSPOST_F(0, 1);
    }

    function test_replay_accrueInterestForSilo() public {
        Tester.mint(157818656604306680780, 0, 0, 0);
        Tester.deposit(252962, 0, 1, 1);
        Tester.borrow(94940, 0, 1);
        _delay(12243);
        Tester.deposit(1, 0, 1, 0);
        _delay(95151);
        Tester.accrueInterestForSilo(1);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Fast forward the time and set up an actor,
    /// @dev Use for ECHIDNA call-traces
    function _delay(uint256 _seconds) internal {
        vm.warp(block.timestamp + _seconds);
    }

    /// @notice Set up an actor
    function _setUpActor(address _origin) internal {
        actor = actors[_origin];
    }

    /// @notice Set up an actor and fast forward the time
    /// @dev Use for ECHIDNA call-traces
    function _setUpActorAndDelay(address _origin, uint256 _seconds) internal {
        actor = actors[_origin];
        vm.warp(block.timestamp + _seconds);
    }

    /// @notice Set up a specific block and actor
    function _setUpBlockAndActor(uint256 _block, address _user) internal {
        vm.roll(_block);
        actor = actors[_user];
    }

    /// @notice Set up a specific timestamp and actor
    function _setUpTimestampAndActor(uint256 _timestamp, address _user) internal {
        vm.warp(_timestamp);
        actor = actors[_user];
    }
}
