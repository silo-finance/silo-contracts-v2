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

    /// @dev Needed in order for foundry to recognise the contract as a test, faster debugging
    function testAux() public {}

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                FAILING INVARIANTS REPLAY                                  //
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
        this.setDaoFee(0,2877132025);
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
    //                              FAILING POSTCONDITIONS REPLAY                                //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function test_borrowSameAssetEchidna() public {
        this.mint(2006, 0, 0, 1);
        this.borrowSameAsset(1, 0, 0);
    }

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

    function test_replayflashLoan() public {
        Tester.flashLoan(0, 0, 0, 0);
    }

    function test_replayrepay() public {
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(415353);
        Tester.deposit(6061261593023587147818, 7, 10, 81);
        _setUpActor(0x0000000000000000000000000000000000020000);
        _delay(134471);
        Tester.mint(1313373040, 67, 21, 47);
        _delay(474988);
        Tester.borrow(1, 0, 0);
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(312375);
        Tester.deposit(9444732965739290427391, 27, 139, 254);
        _delay(160282);
        Tester.assertBORROWING_HSPOST_F(64, 68);
        _setUpActor(0x0000000000000000000000000000000000020000);
        _delay(438166);
        Tester.transfer(90150582660208773834348973696085448347371201314591338751880207669366116432957, 5, 18);
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(424755);
        Tester.borrow(1, 0, 0);
        _setUpActor(0x0000000000000000000000000000000000020000);
        _delay(510507);
        Tester.repayShares(520555292427036831668360898936693814556974953900574298614686473305077297038, 48, 249);
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(587373);
        Tester.transferFrom(115792089237316195423570985008687907853269984665640564039456584007913129639935, 31, 99, 39);
        _delay(407909);
        Tester.accrueInterestForBothSilos();
        _delay(322364);
        Tester.transfer(19291303182811771215250568409802302915840668716053487739932194246753028344693, 168, 42);
        _delay(452189);
        Tester.transfer(128429066822423294821179430796873395062620750747452622196254867, 167, 129);
        _delay(516957);
        Tester.liquidationCall(
            10260803727853885663428982578097453009695898836948938082162141490862812813330,
            false,
            RandomGenerator(156, 58, 148)
        );
        Tester.repay(78, 133, 30);
    }

    function test_replayassertBORROWING_HSPOST_F() public {
        Tester.setOraclePrice(10526380859944180462329986180594915923664232381716724045, 0);
        Tester.setOraclePrice(0, 1);
        Tester.deposit(3378525105089190668364100193, 0, 1, 1);
        Tester.mint(125502909608, 0, 0, 0);
        Tester.assertBORROWING_HSPOST_F(0, 1);
    }

    function test_replayassert_LENDING_INVARIANT_B() public {
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(326792);
        Tester.mint(340282423155723237052512385577070742059, 30, 112, 137);
        _setUpActor(0x0000000000000000000000000000000000020000);
        _delay(452492);
        Tester.mint(1023, 0, 0, 0);
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(315353);
        Tester.mint(37, 2, 0, 173);
        _delay(474683);
        Tester.deposit(3121116753, 199, 132, 32);
        _setUpActor(0x0000000000000000000000000000000000020000);
        _delay(578494);
        Tester.borrowSameAsset(699, 159, 120);
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(220265);
        Tester.assert_LENDING_INVARIANT_B(164, 49);
        _setUpActor(0x0000000000000000000000000000000000030000);
        _delay(537686);
        Tester.assert_BORROWING_HSPOST_D(48, 10);
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(358874);
        Tester.repayShares(115792089237316195423570985008687907853269984665640564039457584007910333092459, 137, 189);
        _setUpActor(0x0000000000000000000000000000000000020000);
        _delay(276464);
        Tester.borrowShares(789, 132, 7);
        _setUpActor(0x0000000000000000000000000000000000030000);
        _delay(342311);
        Tester.mint(32149610478027680347583341753523034074038722701246383246579045092108030590111, 160, 70, 109);
        _delay(102108);
        Tester.approve(51937244289336444957445090528459496937986626001158034643062, 88, 0);
        _delay(45912);
        Tester.repayShares(878, 121, 179);
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(95199);
        Tester.switchCollateralToThisSilo(160);
        _setUpActor(0x0000000000000000000000000000000000030000);
        _delay(554801);
        Tester.decreaseReceiveAllowance(1524785992, 55, 14);
        _delay(160505);
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(575105);
        Tester.transfer(3339332542767618516007464591955998462724103023620318046077463113018338521033, 66, 175);
        _setUpActor(0x0000000000000000000000000000000000020000);
        _delay(411916);
        Tester.setOraclePrice(1001, 41);
        _delay(322367);
        Tester.setOraclePrice(114217138138726068987647614486445875919419044991344712780274345728802549048355, 195);
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(150736);
        Tester.setReceiveApproval(99999999999999999, 4, 161);
        _delay(65535);
        Tester.borrowSameAsset(53481355200196777169969112923058082324140503777788502153038227781653533927158, 0, 108);
        _setUpActor(0x0000000000000000000000000000000000020000);
        _delay(322289);
        Tester.transfer(3574117792, 220, 2);
        _setUpActor(0x0000000000000000000000000000000000030000);
        _delay(50435);
        Tester.decreaseReceiveAllowance(
            83707498239647981397465107311606052962400530930157546111810393385972674224550, 62, 27
        );
        _delay(10674);
        Tester.accrueInterestForBothSilos();
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(590278);
        Tester.liquidationCall(388, false, RandomGenerator(247, 126, 89));
        _setUpActor(0x0000000000000000000000000000000000030000);
        _delay(511294);
        Tester.accrueInterestForBothSilos();
        _delay(45911);
        Tester.transferFrom(157198259, 56, 181, 19);
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(81682);
        Tester.accrueInterestForBothSilos();
        _setUpActor(0x0000000000000000000000000000000000020000);
        _delay(386819);
        Tester.redeem(714, 41, 11, 8);
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(410220);
        Tester.setOraclePrice(85409458585364639779696574459734764303879900613706863528186209663916725748222, 31);
        _delay(26862);
        _setUpActor(0x0000000000000000000000000000000000030000);
        _delay(554377);
        Tester.borrowShares(486614283760492606901665308033797123565, 244, 0);
        _delay(474986);
        Tester.mint(924, 68, 130, 120);
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(386819);
        Tester.transferFrom(22294535490087355240018312648240589468774068246186732223514078032892988436814, 0, 89, 68);
        _delay(521319);
        Tester.mint(59507230904285265194561683556918288891537395732875019119445909570663440112862, 151, 194, 15);
        _setUpActor(0x0000000000000000000000000000000000030000);
        _delay(370488);
        Tester.assert_BORROWING_HSPOST_D(13, 116);
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(50247);
        Tester.mint(924, 68, 130, 120);
        _setUpActor(0x0000000000000000000000000000000000030000);
        _delay(405856);
        Tester.borrowSameAsset(68, 28, 254);
        _delay(389488);
        Tester.mint(924, 68, 130, 120);
        _delay(114540);
        Tester.assert_LENDING_INVARIANT_B(88, 3);
    }

    function test_replaytransitionCollateral3() public {
        Tester.mint(1, 0, 0, 1);
        Tester.deposit(1, 0, 0, 1);
        Tester.mint(1, 0, 0, 0);
        Tester.mint(1, 0, 0, 0);
        Tester.deposit(5, 0, 0, 0);
        Tester.assert_LENDING_INVARIANT_B(0, 1);
        Tester.transitionCollateral(338, 0, 0, 0);
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
