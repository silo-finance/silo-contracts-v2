// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Utils
import "forge-std/console.sol";
import {Strings} from "openzeppelin5/utils/Strings.sol";

// Contracts
import {SiloVault} from "silo-vaults/contracts/SiloVault.sol";
import {IdleVault} from "silo-vaults/contracts/IdleVault.sol";
import {VaultIncentivesModule} from "silo-vaults/contracts/incentives/VaultIncentivesModule.sol";
import {MockERC4626 as Market} from "./utils/mocks/MockERC4626.sol";
import {PublicAllocator} from "silo-vaults/contracts/PublicAllocator.sol";
import {InvariantsSiloFixture} from
    "silo-vaults/test/enigma-dark-invariants/helpers/fixtures/InvariantsSiloFixture.sol";

// Interfaces
import {ISiloVault} from "silo-vaults/contracts/interfaces/ISiloVault.sol";
import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

// Test Contracts
import {TestERC20} from "silo-vaults/test/enigma-dark-invariants/utils/mocks/TestERC20.sol";
import {BaseTest} from "silo-vaults/test/enigma-dark-invariants/base/BaseTest.t.sol";
import {Actor} from "./utils/Actor.sol";

/// @notice Setup contract for the invariant test Suite, inherited by Tester
contract Setup is BaseTest {
    function _setUp() internal {
        // Deploy core contracts of the protocol
        _deployProtocolCore();

        // Deploy markets
        _createNewMarkets();
    }

    /// @notice Deploy protocol core contracts
    function _deployProtocolCore() internal {
        ALLOCATOR = _makeAddr("Allocator");
        CURATOR = _makeAddr("Curator");
        GUARDIAN = _makeAddr("Guardian");

        SUPPLIER = _makeAddr("Supplier");
        BORROWER = _makeAddr("Borrower");
        REPAYER = _makeAddr("Repayer");
        ONBEHALF = _makeAddr("OnBehalf");
        RECEIVER = _makeAddr("Receiver");

        FEE_RECIPIENT = payable(_makeAddr("FeeRecipient"));
        SKIM_RECIPIENT = _makeAddr("SkimRecipient");

        // Deploy the asset token
        asset = new TestERC20("Asset", "ASSET", 18);
        collateralAsset = new TestERC20("Collateral Asset", "CASSET", 18);
        suiteAssets.push(address(asset));
        suiteAssets.push(address(collateralAsset));

        publicAllocator = new PublicAllocator();

        // Deploy the Incentives Module
        vaultIncentivesModule = new VaultIncentivesModule(OWNER); //TODO setup

        // Deploy the protocol main contracts
        vault = ISiloVault(
            address(new SiloVault(OWNER, TIMELOCK, vaultIncentivesModule, address(asset), "SiloVault Vault", "MMV"))
        );
        vaults.push(vault);
        suiteAssets.push(address(vault));

        idleMarket = new IdleVault(address(vault), address(asset), "idle vault", "idle");
        suiteAssets.push(address(idleMarket)); //TODO remove comment when internal accounting is applied

        vault.setIsAllocator(address(publicAllocator), true);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          MARKETS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _createNewMarkets() internal {
        siloFixture = new InvariantsSiloFixture(FEE_RECIPIENT);

        for (uint256 i; i < NUM_MARKETS; i++) {
            _setupMarket(i);
        }

        // Sort and push to markets array
        _sortLoanMarkets();

        // Must be pushed last.
        markets.push(idleMarket);

        // STORAGE LOGS
        _logArray("unsortedMarkets", unsortedMarkets);
        _logArray("markets", markets);
        _logArray("loanMarketsArray", loanMarketsArray);
        _logArray("collateralMarketsArray", collateralMarketsArray);
        _logArray("silos", silos);
        _logArray("vaults", vaults);
    }

    function _setupMarket(uint256 _marketId) internal returns (IERC4626 market) {
        // Deploy Silo markets
        (ISilo silo0_, ISilo silo1_) = siloFixture.createSilo(address(collateralAsset), address(asset));
        vm.label(address(silo0_), string.concat("Market#", Strings.toString(_marketId)));

        // Store references to allMarkets
        unsortedMarkets.push(silo1_);
        collateralMarkets[silo1_] = silo0_;

        // Store references to each type of market
        loanMarketsArray.push(silo1_);
        collateralMarketsArray.push(silo0_);

        // Add both silos to the vaults array
        vaults.push(silo0_);
        vaults.push(silo1_);

        silos.push(silo0_);
        silos.push(silo1_);

        suiteAssets.push(address(silo0_));
        suiteAssets.push(address(silo1_));
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           ACTORS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Deploy protocol actors and initialize their balances
    function _setUpActors() internal {
        // Initialize the three actors of the fuzzers
        address[] memory addresses = new address[](3);
        addresses[0] = USER1;
        addresses[1] = USER2;
        addresses[2] = USER3;

        // Initialize the tokens array
        address[] memory tokens = new address[](2);
        tokens[0] = address(asset);
        tokens[1] = address(collateralAsset);

        address[] memory contracts_ = new address[](NUM_MARKETS * 2 + 1);
        for (uint256 i; i < silos.length; i++) {
            contracts_[i] = address(silos[i]);
        }
        contracts_[contracts_.length - 1] = address(vault);

        for (uint256 i; i < NUMBER_OF_ACTORS; i++) {
            // Deploy actor proxies and approve system contracts_
            address _actor = _setUpActor(addresses[i], tokens, contracts_);

            // Mint initial balances to actors
            for (uint256 j = 0; j < tokens.length; j++) {
                TestERC20 _token = TestERC20(tokens[j]);
                _token.mint(_actor, INITIAL_BALANCE);
            }
            actorAddresses.push(_actor);
        }
    }

    /// @notice Deploy an actor proxy contract for a user address
    /// @param userAddress Address of the user
    /// @param tokens Array of token addresses
    /// @param contracts_ Array of contract addresses to aprove tokens to
    /// @return actorAddress Address of the deployed actor
    function _setUpActor(address userAddress, address[] memory tokens, address[] memory contracts_)
        internal
        returns (address actorAddress)
    {
        bool success;
        Actor _actor = new Actor(tokens, contracts_);
        actors[userAddress] = _actor;
        (success,) = address(_actor).call{value: INITIAL_ETH_BALANCE}("");
        assert(success);
        actorAddress = address(_actor);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          HELPERS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _sortLoanMarkets() internal {
        uint256 length = unsortedMarkets.length;
        address[] memory sortedMarkets = new address[](length);

        // Copy unsortedMarkets into sortedMarkets
        for (uint256 i = 0; i < length; i++) {
            sortedMarkets[i] = address(unsortedMarkets[i]);
        }

        // Sort using Bubble Sort
        for (uint256 i = 0; i < length - 1; i++) {
            for (uint256 j = 0; j < length - i - 1; j++) {
                if (sortedMarkets[j] > sortedMarkets[j + 1]) {
                    (sortedMarkets[j], sortedMarkets[j + 1]) = (sortedMarkets[j + 1], sortedMarkets[j]);
                }
            }
        }

        // Push sorted addresses into the markets array
        for (uint256 i = 0; i < length; i++) {
            markets.push(IERC4626(sortedMarkets[i]));
        }
    }

    function _logArray(string memory key, IERC4626[] storage array) internal {
        console.log("STORAGE: ", key);
        for (uint256 i; i < array.length; i++) {
            console.log("contract: ", address(array[i]));
        }
        console.log("#####");
    }
}
