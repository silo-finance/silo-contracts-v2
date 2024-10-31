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
        this.setDaoFee(2877132025);
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
        this.assert_LENDING_INVARIANT_C(0, 21);
        echidna_BASE_INVARIANT(); // @audit-ok BASE_INVARIANT_A failing
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
        echidna_BORROWING_INVARIANT();// @audit-ok
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
        //@audit borrowSameAsset does not require any kind of solvency check
        Tester.mint(146189612359507306544594, 0, 0, 1);
        Tester.borrowSameAsset(1, 0, 0);
        Tester.mint(2912, 0, 1, 0);
        Tester.setOraclePrice(259397900503974518365051033297974490300799102382829890910371, 1);
        Tester.switchCollateralToThisSilo(1);
        Tester.setOraclePrice(0, 1);
        Tester.borrowSameAsset(1, 0, 0);
    }

    function test_replayBorrow() public {
        // @audit BASE_GPOST_D
        Tester.mint(3757407288159739, 0, 0, 0);
        Tester.mint(90935896182375204709, 1, 0, 1);
        Tester.borrowSameAsset(1567226244662, 0, 0);
        Tester.assert_LENDING_INVARIANT_C(0, 0);
        Tester.setOraclePrice(0, 0);
        _delay(30);
        Tester.borrowShares(1, 0, 0);
    }

    function test_replayassertBORROWING_HSPOST_F() public {
        // @audit BORROWING_HSPOST_F failing
        Tester.mint(1000, 0, 0, 0);
        Tester.setOraclePrice(1496599498391866130453551051869098196856115, 1);
        Tester.setOraclePrice(886721281625011804659337445, 0);
        Tester.deposit(20, 0, 1, 1);
        Tester.assertBORROWING_HSPOST_F(0, 1);
    }

    function test_replayflashLoan() public {
        // @audit 0 amount flashloan should fail the transaction like the other actions
        Tester.flashLoan(0, 0, 0, 0);
    }

    function test_replaytransitionCollateral() public {
        Tester.mint(1023, 0, 0, 0);
        Tester.transitionCollateral(679, 0, 0, 0);
    }

    function test_replayredeem() public {
        //TODO review with silo team to make sure is desired behavior
        // Mint on silo 0 protected collateral
        Tester.mint(1025, 0, 0, 0);
        Tester.setOraclePrice(282879448546642360938617676663071922922812, 0);

        // Mint on silo 1 collateral
        Tester.mint(36366106112624882, 0, 1, 1);

        // Borrow shares on silo 1 using silo 0 protected collateral as collateral
        Tester.borrowShares(315, 0, 1);

        console.log("########");
        console.log(
            "siloConfig.borrowerCollateralSilo(msg.sender): ", siloConfig.borrowerCollateralSilo(address(actor))
        );

        // Switch collateral from 0 silo 1
        Tester.switchCollateralToThisSilo(1);
        console.log("assert_LENDING_INVARIANT_C");
        // Max Withdraw from silo 1
        Tester.assert_LENDING_INVARIANT_C(1, 1);
        _delay(345519);
        console.log("########");
        console.log("solvent: ", vault0.isSolvent(address(actor)));
        console.log("solvent: ", vault1.isSolvent(address(actor)));
        Tester.redeem(694, 0, 0, 0);
    }

    function test_replaywithdraw0() public {
        // TODO check why echidna is not failing SILO_HSPOST_B
        Tester.withdraw(0, 0, 0, 0);
    }

    function test_replayRedeem0() public {
        // TODO check why echidna is not failing SILO_HSPOST_B
        Tester.redeem(0, 0, 0, 0);
    }

    function test_replayassert_BORROWING_HSPOST_D() public {
        // TODO check why foundry is not failing
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(326792);
        Tester.mint(340282423155723237052512385577070742059, 30, 112, 137);
        _setUpActor(0x0000000000000000000000000000000000020000);
        _delay(452188);
        Tester.deposit(2835717307, 103, 167, 147);
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(322275);
        Tester.setOraclePrice(55280569312692373490196013056808227806891853791735344918874142698213660412305, 23);
        _setUpActor(0x0000000000000000000000000000000000020000);
        _delay(32767);
        Tester.assertBORROWING_HSPOST_F(64, 78);
        _delay(509126);
        Tester.borrowShares(47, 3, 32);
        _delay(502419);
        _delay(436472);
        Tester.mint(924, 68, 130, 120);
        _setUpActor(0x0000000000000000000000000000000000030000);
        _delay(322342);
        Tester.approve(115792089237316195423570985008687907853269984665640564039456634007913129639936, 253, 40);
        _delay(272130);
        Tester.assert_LENDING_INVARIANT_C(24, 117);
        _delay(336899);
        Tester.switchCollateralToThisSilo(17);
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(267435);
        Tester.liquidationCall(
            55274039173466044573085824002369434721392944367468590368902904918998252794001,
            true,
            RandomGenerator(227, 8, 87)
        );
        _setUpActor(0x0000000000000000000000000000000000030000);
        _delay(309983);
        Tester.accrueInterestForSilo(57);
        _setUpActor(0x0000000000000000000000000000000000020000);
        _delay(290782);
        Tester.transfer(100000000000000001, 8, 67);
        _setUpActor(0x0000000000000000000000000000000000030000);
        _delay(322328);
        Tester.repayShares(174197950, 4, 244);
        _setUpActor(0x0000000000000000000000000000000000020000);
        _delay(253699);
        Tester.approve(115792089237316195423570985008687907853269984665640564039456634007913129639936, 253, 40);
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(322328);
        Tester.increaseReceiveAllowance(
            79938786390973806961901524534113156724645984534916293209236827952587128622943, 111, 10
        );
        _delay(242555);
        Tester.liquidationCall(388, false, RandomGenerator(247, 126, 89));
        _setUpActor(0x0000000000000000000000000000000000020000);
        _delay(577105);
        Tester.decreaseReceiveAllowance(
            45963211144775969831521803001089376361106655514834038343524209057669939837309, 1, 164
        );
        _setUpActor(0x0000000000000000000000000000000000030000);
        _delay(448251);
        Tester.repayShares(174197950, 4, 244);
        _setUpActor(0x0000000000000000000000000000000000020000);
        _delay(322326);
        Tester.approve(40, 4, 8);
        _delay(144223);
        _setUpActor(0x0000000000000000000000000000000000010000);
        _delay(225906);
        Tester.assert_BORROWING_HSPOST_D(193, 42);
    }

    function test_replaytransitionCollateral2() public {
        Tester.mint(4003, 0, 0, 0);
        Tester.mint(4142174, 0, 1, 1);
        Tester.setOraclePrice(5167899937944767889217962943343171205019348763, 0);
        Tester.assertBORROWING_HSPOST_F(0, 1);
        Tester.setOraclePrice(2070693789985146455311434266782705402030751026, 1);
        Tester.transitionCollateral(2194, 0, 0, 0);
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
