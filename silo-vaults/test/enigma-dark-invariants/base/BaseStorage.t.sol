// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries

// Contracts
import {PublicAllocator} from "silo-vaults/contracts/PublicAllocator.sol";
import {VaultIncentivesModule} from "silo-vaults/contracts/incentives/VaultIncentivesModule.sol";

// Interfaces
import {ISiloVault} from "silo-vaults/contracts/interfaces/ISiloVault.sol";
import {IERC4626, IERC20} from "openzeppelin5/interfaces/IERC4626.sol";

// Mock Contracts
import {TestERC20} from "silo-vaults/test/enigma-dark-invariants/utils/mocks/TestERC20.sol";

// Utils
import {Actor} from "../utils/Actor.sol";

/// @notice BaseStorage contract for all test contracts, works in tandem with BaseTest
abstract contract BaseStorage {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       CONSTANTS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    uint256 constant MAX_TOKEN_AMOUNT = 1e29;

    uint256 constant ONE_DAY = 1 days;
    uint256 constant ONE_MONTH = ONE_YEAR / 12;
    uint256 constant ONE_YEAR = 365 days;

    uint256 internal constant NUMBER_OF_ACTORS = 3;
    uint256 internal constant INITIAL_ETH_BALANCE = 1e26;
    uint256 internal constant INITIAL_COLL_BALANCE = 1e21;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ACTORS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Stores the actor during a handler call
    Actor internal actor;

    /// @notice Mapping of fuzzer user addresses to actors
    mapping(address => Actor) internal actors;

    /// @notice Array of all actor addresses
    address[] internal actorAddresses;

    /// @notice The address that is targeted when executing an action
    address internal targetActor;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                     RELEVANT ADDRESSES                                    //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    address internal OWNER = address(this);
    address internal ALLOCATOR;
    address internal CURATOR;
    address internal GUARDIAN;

    address internal SUPPLIER;
    address internal BORROWER;
    address internal REPAYER;
    address internal ONBEHALF;
    address internal RECEIVER;

    address payable internal FEE_RECIPIENT;
    address internal SKIM_RECIPIENT;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       SUITE STORAGE                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    // Main contract of the suite
    ISiloVault internal vault;

    // "Fake" Market for the suite
    IERC4626 internal idleMarket;

    PublicAllocator internal publicAllocator;

    VaultIncentivesModule internal vaultIncentivesModule;

    // Test Assets
    TestERC20 internal asset;

    // Test Markets
    IERC4626 internal market1;
    IERC4626 internal market2;
    IERC4626 internal market3;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       EXTRA VARIABLES                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Array of markets for the suite
    address[] internal markets;

    /// @notice Array of markets for the suite
    address[] internal unsortedMarkets;

    /// @notice Array of all 4626 vaults on the suite
    address[] internal vaults;

    /// @notice Permit2 contract
    address permit2;

    address targetMarket;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          STRUCTS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
