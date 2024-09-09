// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Contracts
import {Silo, ISilo} from "silo-core/contracts/Silo.sol";
import {PartialLiquidation} from "silo-core/contracts/utils/hook-receivers/liquidation/PartialLiquidation.sol";


// Mock Contracts
import {
    TestERC20
} from "../utils/mocks/TestERC20.sol";

// Test Contracts

// Utils
import {Actor} from "../utils/Actor.sol";

// Interfaces
import {ISiloConfig} from "silo-core/contracts/SiloConfig.sol";
import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";
import {IInterestRateModelV2Config, InterestRateModelV2Config} from "silo-core/contracts/interestRateModel/InterestRateModelV2Config.sol";
import {IInterestRateModelV2ConfigFactory, InterestRateModelV2ConfigFactory} from "silo-core/contracts/interestRateModel/InterestRateModelV2ConfigFactory.sol";
import {IInterestRateModelV2, InterestRateModelV2} from "silo-core/contracts/interestRateModel/InterestRateModelV2.sol";
import {IGaugeHookReceiver, GaugeHookReceiver} from "silo-core/contracts/utils/hook-receivers/gauge/GaugeHookReceiver.sol";
import {ISiloDeployer, SiloDeployer} from "silo-core/contracts/SiloDeployer.sol";


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

    /// @notice The pool admin is set to this contract, the Tester contract
    address internal poolAdmin = address(this);

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       SUITE STORAGE                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    // PROTOCOL CONTRACTS

    /// @notice The two silos of a market
    address internal _vault0;
    address internal _vault1;
    Silo internal vault0;
    Silo internal vault1;

	/// @notice Protocol factories
    ISiloFactory siloFactory;
    ISiloFactory siloFactoryInternal;
    IInterestRateModelV2ConfigFactory interestRateModelV2ConfigFactory;

	/// @notice The interest rate model for the market
    IInterestRateModelV2 interestRateModelV2;

	/// @notice Secondary contracts
    IGaugeHookReceiver hookReceiver;
    ISiloDeployer siloDeployer;
    PartialLiquidation liquidationModule;

    // ASSETS

    TestERC20 internal _asset0;
    TestERC20 internal _asset1;

    // CONFIGURATION

    ISiloConfig internal siloConfig;

    mapping(string IRMConfigName => address IRMConfigAddress) internal IRMConfigs;

    // MOCKS

	address internal oracle0;
	address internal oracle1;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       EXTRA VARIABLES                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Array of base assets for the suite
    address[] internal baseAssets;

    /// @notice Array of silos for the suite
    address[] internal silos;

    /// @notice Mapping of silo init data
	mapping(string identifier => ISiloConfig.InitData siloInitData) internal siloData;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          STRUCTS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
