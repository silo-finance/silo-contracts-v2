// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries

// Contracts
import {PublicAllocator} from "silo-vaults/contracts/PublicAllocator.sol";
import {VaultIncentivesModule} from "silo-vaults/contracts/incentives/VaultIncentivesModule.sol";
import {InvariantsSiloFixture} from
    "silo-vaults/test/enigma-dark-invariants/helpers/fixtures/InvariantsSiloFixture.sol";

// Interfaces
import {ISiloVault} from "silo-vaults/contracts/interfaces/ISiloVault.sol";
import {IPartialLiquidation} from "silo-core/contracts/interfaces/IPartialLiquidation.sol";
import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

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
    TestERC20 internal collateralAsset;

    // Silo fixture
    InvariantsSiloFixture internal siloFixture;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       EXTRA VARIABLES                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    // LOAN MARKETS

    /// @notice Array of markets for the suite
    IERC4626[] internal markets;

    /// @notice Array of markets for the suite
    IERC4626[] internal unsortedMarkets;

    // COLLATERAL MARKETS

    /// @notice Array of collateral markets for the suite
    IERC4626[] internal loanMarketsArray;

    /// @notice Array of collateral markets for the suite
    IERC4626[] internal collateralMarketsArray;

    /// @notice Mapping of loan markets to collateral markets
    mapping(IERC4626 collateral => IERC4626) internal collateralMarkets;

    // VAULTS (MARKETS AND SILO VAULT)

    /// @notice Array of all 4626 vaults on the suite
    IERC4626[] internal vaults;

    /// @notice Array of all silos on suite -> markets & collateral markets
    IERC4626[] internal silos;

    // SUITE ASSETS

    /// @notice All ERC20 assets on the suite including vaults share tokens and loan and collateral assets
    address[] suiteAssets;

    address targetMarket;

    // HELPER CONTRACTS

    /// @notice Permit2 contract
    address permit2;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          STRUCTS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
