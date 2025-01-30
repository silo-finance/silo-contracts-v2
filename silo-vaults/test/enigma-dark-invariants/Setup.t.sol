// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Utils
import "forge-std/console.sol";

// Contracts
import {SiloVault} from "silo-vaults/contracts/SiloVault.sol";
import {IdleVault} from "silo-vaults/contracts/IdleVault.sol";
import {VaultIncentivesModule} from "silo-vaults/contracts/incentives/VaultIncentivesModule.sol";
import {MockERC4626 as Market} from "./utils/mocks/MockERC4626.sol";
import {PublicAllocator} from "silo-vaults/contracts/PublicAllocator.sol";

// Interfaces
import {ISiloVault} from "silo-vaults/contracts/interfaces/ISiloVault.sol";
import {IERC4626, IERC20} from "openzeppelin5/interfaces/IERC4626.sol";

// Test Contracts
import {TestERC20} from "silo-vaults/test/enigma-dark-invariants/utils/mocks/TestERC20.sol";
import {BaseTest} from "silo-vaults/test/enigma-dark-invariants/base/BaseTest.t.sol";
import {Actor} from "./utils/Actor.sol";

/// @notice Setup contract for the invariant test Suite, inherited by Tester
contract Setup is
    BaseTest
{
    function _setUp() internal {
        // Deploy core contracts of the protocol
        _deployProtocolCore();

        // Deploy markets
        _deployMarkets();
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

        publicAllocator = new PublicAllocator();

        // Deploy the Incentives Module
        vaultIncentivesModule = new VaultIncentivesModule(OWNER); //TODO setup 

        // Deploy the protocol main contracts
        vault = ISiloVault(
            address(new SiloVault(OWNER, TIMELOCK, vaultIncentivesModule, address(asset), "SiloVault Vault", "MMV"))
        );
        vaults.push(address(vault));
        idleMarket = new IdleVault(address(vault), address(asset), "idle vault", "idle");

        vault.setIsAllocator(address(publicAllocator), true);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          MARKETS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _deployMarkets() internal {
        // Deploy markets
        market1 = _deployMarket(address(asset));
        unsortedMarkets.push(address(market1));
        vaults.push(address(market1));

        market2 = _deployMarket(address(asset));
        unsortedMarkets.push(address(market2));
        vaults.push(address(market2));

        market3 = _deployMarket(address(asset));
        unsortedMarkets.push(address(market3));
        vaults.push(address(market3));

        // Sort and push to markets array
        _sortAndStoreMarkets();
    }

    function _deployMarket(address asset) internal returns (IERC4626 market) {
        // TODO implement Silo's instead
        market = new Market(asset, "default market", "market");
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
        address[] memory tokens = new address[](1);
        tokens[0] = address(asset);

        address[] memory contracts_ = new address[](1);
        contracts_[0] = address(vault);

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

    function _sortAndStoreMarkets() internal {
        uint256 length = unsortedMarkets.length;
        address[] memory sortedMarkets = new address[](length);

        // Copy unsortedMarkets into sortedMarkets
        for (uint256 i = 0; i < length; i++) {
            sortedMarkets[i] = unsortedMarkets[i];
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
            markets.push(sortedMarkets[i]);
        }
    }
}
