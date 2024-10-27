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
    modifier setup() override {
        _;
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
    }

    /// @dev Needed in order for foundry to recognise the contract as a test, faster debugging
    function testAux() public {}

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                FAILING INVARIANTS REPLAY                                  //
    ///////////////////////////////////////////////////////////////////////////////////////////////

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

    function test_echidna_BASE_INVARIANT1() public {
        this.leverageSameAsset(2, 1, 0, 0, 0);
        echidna_BASE_INVARIANT();
    }

    function test_echidna_BASE_INVARIANT2() public {
        this.leverageSameAsset(433, 318, 0, 0, 1);
        _delay(425435);
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
        echidna_BASE_INVARIANT();// @audit BASE_INVARIANT_A failing
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                              FAILING POSTCONDITIONS REPLAY                                //
    ///////////////////////////////////////////////////////////////////////////////////////////////

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
