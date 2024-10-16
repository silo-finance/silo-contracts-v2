// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Utils
import {Actor} from "./utils/Actor.sol";

// Contracts
import {SiloFactory} from "silo-core/contracts/SiloFactory.sol";
import {Silo} from "silo-core/contracts/Silo.sol";
import {SiloInternal} from "../echidna/internal_testing/SiloInternal.sol";
import {
    ShareProtectedCollateralToken
} from "silo-core/contracts/utils/ShareProtectedCollateralToken.sol";
import {ShareDebtToken} from "silo-core/contracts/utils/ShareDebtToken.sol";
import {
    IInterestRateModelV2,
    InterestRateModelV2
} from "silo-core/contracts/interestRateModel/InterestRateModelV2.sol";
import {
    IGaugeHookReceiver,
    GaugeHookReceiver
} from "silo-core/contracts/utils/hook-receivers/gauge/GaugeHookReceiver.sol";
import {
    PartialLiquidation
} from "silo-core/contracts/utils/hook-receivers/liquidation/PartialLiquidation.sol";
import {
    ISiloDeployer,
    SiloDeployer
} from "silo-core/contracts/SiloDeployer.sol";

// Test Contracts
import {BaseTest} from "./base/BaseTest.t.sol";
import {MockFlashLoanReceiver} from "./helpers/FlashLoanReceiver.sol";

// Mock Contracts
import {TestERC20} from "./utils/mocks/TestERC20.sol";
import {MockSiloOracle} from "./utils/mocks/MockSiloOracle.sol";

// Interfaces
import {ISiloConfig, SiloConfig} from "silo-core/contracts/SiloConfig.sol";
import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";
import {
    IInterestRateModelV2ConfigFactory,
    InterestRateModelV2ConfigFactory
} from "silo-core/contracts/interestRateModel/InterestRateModelV2ConfigFactory.sol";
import {
    IInterestRateModelV2Config,
    InterestRateModelV2Config
} from "silo-core/contracts/interestRateModel/InterestRateModelV2Config.sol";
import {ISilo} from "silo-core/contracts/Silo.sol";

/// @notice Setup contract for the invariant test Suite, inherited by Tester
contract Setup is BaseTest {
    function _setUp() internal {
        // Deploy protocol contracts and protocol actors
        _deployProtocolCore();
    }

    /// @notice Deploy protocol core contracts
    function _deployProtocolCore() internal {
        // Deploy protocol core contracts
        core_deploySiloLiquidation();
        core_deploySiloFactory(address(this));
        core_deployInterestRateConfigFactory();
        core_deployInterestRateModel();
        core_deployGaugeHookReceiver();
        core_deploySiloDeployer();

        // Deploy assets
        _deployAssets();
        // Deploy Oracles
        _deployOracles();

        // Create silos
        _initData(address(_asset0), address(_asset1));
        siloConfig = siloFactory.createSilo(siloData["MOCK"]);
        (_vault0, _vault1) = siloConfig.getSilos();
        silos.push(_vault0);
        silos.push(_vault1);
        vault0 = Silo(payable(_vault0));
        vault1 = Silo(payable(_vault1));

        // Store all collateral (silos) & debt shareTokens in an array
        shareTokens.push(_vault0);
        shareTokens.push(_vault1);
        (address debtToken0, ) = siloConfig.getDebtShareTokenAndAsset(
            address(vault0)
        );
        shareTokens.push(debtToken0);
        (address debtToken1, ) = siloConfig.getDebtShareTokenAndAsset(
            address(vault1)
        );
        shareTokens.push(debtToken1);

        debtTokens.push(debtToken0);
        debtTokens.push(debtToken1);

        // Store the protected collateral tokens in an array
        (, address protectedCollateralToken0) = siloConfig
            .getCollateralShareTokenAndAsset(
            address(vault0),
            ISilo.CollateralType.Protected
        );

        (, address protectedCollateralToken1) = siloConfig
            .getCollateralShareTokenAndAsset(
            address(vault1),
            ISilo.CollateralType.Protected
        );

        protectedTokens.push(protectedCollateralToken0);
        protectedTokens.push(protectedCollateralToken1);

        liquidationModule = PartialLiquidation(
            vault0.config().getConfig(_vault0).hookReceiver
        );
        liquidationModule.initialize(siloConfig, "");

        flashLoanReceiver = address(new MockFlashLoanReceiver());
    }

    /// @notice Deploy protocol actors and initialize their balances
    function _setUpActors() internal {
        // Initialize the three actors of the fuzzers
        address[] memory addresses = new address[](3);
        addresses[0] = USER1;
        addresses[1] = USER2;
        addresses[2] = USER3;

        // Initialize the tokens array
        address[] memory tokens = new address[](2);
        tokens[0] = address(_asset0);
        tokens[1] = address(_asset1);

        address[] memory contracts = new address[](3);
        contracts[0] = address(_vault0);
        contracts[1] = address(_vault1);
        contracts[2] = address(liquidationModule);

        for (uint256 i; i < NUMBER_OF_ACTORS; i++) {
            // Deploy actor proxies and approve system contracts
            address _actor = _setUpActor(addresses[i], tokens, contracts);

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
    /// @param contracts Array of contract addresses to aprove tokens to
    /// @return actorAddress Address of the deployed actor
    function _setUpActor(
        address userAddress,
        address[] memory tokens,
        address[] memory contracts
    ) internal returns (address actorAddress) {
        bool success;
        Actor _actor = new Actor(tokens, contracts);
        actors[userAddress] = _actor;
        (success, ) = address(_actor).call{value: INITIAL_ETH_BALANCE}("");
        assert(success);
        actorAddress = address(_actor);
    }

    function core_deploySiloFactory(address feeReceiver) internal {
        siloFactory = ISiloFactory(address(new SiloFactory()));
        siloFactoryInternal = ISiloFactory(address(new SiloFactory()));

        address siloImpl = address(new Silo(siloFactory));
        address siloImplInternal = address(
            new SiloInternal(siloFactoryInternal)
        );

        address shareProtectedCollateralTokenImpl = address(
            new ShareProtectedCollateralToken()
        );
        address shareDebtTokenImpl = address(new ShareDebtToken());

        uint256 daoFee = 0.15e18;
        address daoFeeReceiver = feeReceiver == address(0)
            ? address(0)
            : feeReceiver;

        siloFactory.initialize(
            siloImpl,
            shareProtectedCollateralTokenImpl,
            shareDebtTokenImpl,
            daoFee,
            daoFeeReceiver
        );

        siloFactoryInternal.initialize(
            siloImplInternal,
            shareProtectedCollateralTokenImpl,
            shareDebtTokenImpl,
            daoFee,
            daoFeeReceiver
        );
    }

    function core_deployInterestRateConfigFactory() internal {
        interestRateModelV2ConfigFactory = IInterestRateModelV2ConfigFactory(
            address(new InterestRateModelV2ConfigFactory())
        );


            IInterestRateModelV2.Config memory interestRateModelConfig
         = IInterestRateModelV2.Config({
            uopt: 500000000000000000,
            ucrit: 900000000000000000,
            ulow: 300000000000000000,
            ki: 146805,
            kcrit: 317097919838,
            klow: 105699306613,
            klin: 4439370878,
            beta: 69444444444444
        });

        // deploy preset IRM configs
        (, IInterestRateModelV2Config config) = interestRateModelV2ConfigFactory
            .create(interestRateModelConfig);
        IRMConfigs["defaultAsset"] = address(config);
    }

    function core_deployInterestRateModel() internal {
        interestRateModelV2 = IInterestRateModelV2(
            address(new InterestRateModelV2())
        );
    }

    function core_deployGaugeHookReceiver() internal {
        hookReceiver = IGaugeHookReceiver(address(new GaugeHookReceiver()));
    }

    function core_deploySiloLiquidation() internal {
        liquidationModule = new PartialLiquidation();
    }

    function core_deploySiloDeployer() internal {
        siloDeployer = ISiloDeployer(
            address(
                new SiloDeployer(interestRateModelV2ConfigFactory, siloFactory)
            )
        );
    }

    function _deployAssets() internal {
        _asset0 = new TestERC20("Test Token0", "TT0", 18);
        _asset1 = new TestERC20("Test Token1", "TT1", 6);
        baseAssets.push(address(_asset0));
        baseAssets.push(address(_asset1));
    }

    function _deployOracles() internal {
        oracle0 = address(new MockSiloOracle(1 ether, address(_asset1)));
        oracle1 = address(new MockSiloOracle(1 ether, address(_asset0)));
    }

    function _initData(address mock0, address mock1) internal {
        // The FULL data relies on addresses set in _setupBasicData()
        siloData["FULL"] = ISiloConfig.InitData({
            deployer: address(this),
            deployerFee: 0.1000e18,
            token0: address(_asset0),
            solvencyOracle0: oracle0,
            maxLtvOracle0: oracle0,
            interestRateModel0: address(interestRateModelV2),
            interestRateModelConfig0: IRMConfigs["defaultAsset"],
            maxLtv0: 0.7500e18,
            lt0: 0.8500e18,
            liquidationFee0: 0.0500e18,
            flashloanFee0: 0.0100e18,
            callBeforeQuote0: true,
            hookReceiver: address(liquidationModule),
            token1: address(_asset1),
            solvencyOracle1: oracle1,
            maxLtvOracle1: oracle1,
            interestRateModel1: address(interestRateModelV2),
            interestRateModelConfig1: IRMConfigs["defaultAsset"],
            maxLtv1: 0.8500e18,
            lt1: 0.9500e18,
            liquidationFee1: 0.0250e18,
            flashloanFee1: 0.0100e18,
            callBeforeQuote1: true
        });

        // We set up the mock data, without oracles and receivers
        ISiloConfig.InitData memory mocks = siloData["FULL"];
        mocks.token0 = mock0;
        mocks.token1 = mock1;
        mocks.maxLtvOracle0 = address(0); // TODO configure max ltv oracle
        mocks.maxLtvOracle1 = address(0);
        mocks.callBeforeQuote0 = false;
        mocks.callBeforeQuote1 = false;

        siloData["MOCK"] = mocks;
    }
}
