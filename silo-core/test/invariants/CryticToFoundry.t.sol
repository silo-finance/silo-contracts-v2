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

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                 BROKEN INVARIANTS REPLAY                                  //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @dev Needed in order for foundry to recognise the contract as a test, faster debugging
    function testAux() public {}

    function test_echidna_BASE_INVARIANT() public {
        this.leverageSameAsset(2, 1, 0, 0, 0);
        echidna_BASE_INVARIANT();
    }

    function test_echidna_BORROWING_INVARIANT() public {
        this.leverageSameAsset(2, 1, 0, 0, 0);
        echidna_BORROWING_INVARIANT();
    }

    function test_echidna_BASE_INVARIANT2() public {
        _setUpActorAndDelay(USER1, 461381);
        this.setOraclePrice(83076749736557242056487941267521536,99);
        _setUpActorAndDelay(USER2, 4381);
        **wait for 123 seconds**
        this.leverageSameAsset(2417851639229258349412352,84666295960563771947693112236492259590132031432159098261997530209880644297589,29,245,133);
        echidna_BASE_INVARIANT();
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
    function _setUpTimestampAndActor(uint256 _timestamp, address _user)
        internal
    {
        vm.warp(_timestamp);
        actor = actors[_user];
    }
}
