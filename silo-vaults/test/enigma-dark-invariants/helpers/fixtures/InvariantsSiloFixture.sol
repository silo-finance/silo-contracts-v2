// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Utils
import {Clones} from "openzeppelin5/proxy/Clones.sol";

// Contracts
import {SiloFactory} from "silo-core/contracts/SiloFactory.sol";
import {Silo} from "silo-core/contracts/Silo.sol";
import {ShareProtectedCollateralToken} from "silo-core/contracts/utils/ShareProtectedCollateralToken.sol";
import {ShareDebtToken} from "silo-core/contracts/utils/ShareDebtToken.sol";
import {InterestRateModelV2} from "silo-core/contracts/interestRateModel/InterestRateModelV2.sol";
import {SiloHookV1} from "silo-core/contracts/utils/hook-receivers/SiloHookV1.sol";
import {CloneDeterministic} from "silo-core/contracts/lib/CloneDeterministic.sol";
import {Views} from "silo-core/contracts/lib/Views.sol";

// Test Contracts

// Mock Contracts

// Interfaces
import {ISiloConfig, SiloConfig} from "silo-core/contracts/SiloConfig.sol";
import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";
import {
    IInterestRateModelV2Factory,
    InterestRateModelV2Factory
} from "silo-core/contracts/interestRateModel/InterestRateModelV2Factory.sol";
import {
    IInterestRateModelV2Config,
    InterestRateModelV2Config
} from "silo-core/contracts/interestRateModel/InterestRateModelV2Config.sol";
import {IInterestRateModelV2} from "silo-core/contracts/interestRateModel/InterestRateModelV2.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

/// @notice Fixture contract to deploy silo core contracts for the enigma invariant suites
contract InvariantsSiloFixture {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      STATE VARIABLES                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ISiloConfig public siloConfig;
    ISiloFactory public siloFactory;
    ISiloFactory public siloFactoryInternal;
    IInterestRateModelV2Factory public interestRateModelV2ConfigFactory;
    IInterestRateModelV2.Config public presetIRMConfig;
    IInterestRateModelV2 public interestRateModelV2;
    address deployer_;
    address creator_;
    address oracle0;
    address oracle1;

    //mapping(string => ISiloConfig.InitData) public siloData;

    constructor(address feeReceiver, address _deployer) {
        // Deploy core contracts and factory
        core_deploySiloCoreContracts();
        core_deploySiloFactory(feeReceiver);

        // Interest rate model
        core_deployInterestRateConfigFactory();
        core_deployInterestRateModel();

        deployer_ = _deployer;
        creator_ = msg.sender;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       EXTERNAL FUNCTIONS                                  //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function createSilo(address asset0, address asset1) external returns (ISilo vault0, ISilo vault1) {
        address siloImpl = address(new Silo(siloFactory));

        address shareProtectedCollateralTokenImpl = address(new ShareProtectedCollateralToken());
        address shareDebtTokenImpl = address(new ShareDebtToken());

        // Deploy SiloHookV1
        address siloHookImplementation = address(new SiloHookV1());
        SiloHookV1 siloHook = SiloHookV1(Clones.cloneDeterministic(siloHookImplementation, bytes32(0)));

        // deploy silo config
        ISiloConfig.InitData memory siloInitData = _getInitData(asset0, asset1, address(siloHook));
        siloConfig = _deploySiloConfig(siloInitData, siloImpl, shareProtectedCollateralTokenImpl, shareDebtTokenImpl);

        // deploy silo
        siloFactory.createSilo(
            siloConfig,
            siloImpl,
            shareProtectedCollateralTokenImpl,
            shareDebtTokenImpl,
            siloInitData.deployer,
            creator_
        );

        (address _vault0, address _vault1) = siloConfig.getSilos();
        vault0 = ISilo(payable(_vault0));
        vault1 = ISilo(payable(_vault1));

        // Initialize the liquidation module
        siloHook.initialize(siloConfig, abi.encode(deployer_));
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                  SILO CUSTOM SETUP FUNCTIONS                              //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function core_deploySiloCoreContracts() internal {
        // Liquidation module
    }

    function core_deploySiloFactory(address feeReceiver) internal {
        uint256 daoFee = 0.15e18;
        address daoFeeReceiver = feeReceiver == address(0) ? address(0) : feeReceiver;

        siloFactory = ISiloFactory(address(new SiloFactory(daoFeeReceiver)));
        siloFactoryInternal = ISiloFactory(address(new SiloFactory(daoFeeReceiver)));
    }

    function core_deployInterestRateConfigFactory() internal {
        interestRateModelV2ConfigFactory = IInterestRateModelV2Factory(address(new InterestRateModelV2Factory()));
        // set preset IRM configs
        presetIRMConfig = IInterestRateModelV2.Config({
            uopt: 500000000000000000,
            ucrit: 900000000000000000,
            ulow: 300000000000000000,
            ki: 146805,
            kcrit: 317097919838,
            klow: 105699306613,
            klin: 4439370878,
            beta: 69444444444444,
            ri: 0,
            Tcrit: 0
        });
    }

    function core_deployInterestRateModel() internal {
        (, interestRateModelV2) = interestRateModelV2ConfigFactory.create(presetIRMConfig);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                     DEPLOYMENT HELPERS                                    //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _deploySiloConfig(
        ISiloConfig.InitData memory _siloInitData,
        address _siloImpl,
        address _shareProtectedCollateralTokenImpl,
        address _shareDebtTokenImpl
    ) internal returns (ISiloConfig _siloConfig) {
        uint256 nextSiloId = siloFactory.getNextSiloId();

        uint256 creatorSiloCounter = siloFactory.creatorSiloCounter(creator_);

        ISiloConfig.ConfigData memory configData0;
        ISiloConfig.ConfigData memory configData1;

        (configData0, configData1) = Views.copySiloConfig(
            _siloInitData,
            siloFactory.daoFeeRange(),
            siloFactory.maxDeployerFee(),
            siloFactory.maxFlashloanFee(),
            siloFactory.maxLiquidationFee()
        );

        configData0.silo = CloneDeterministic.predictSilo0Addr(_siloImpl, creatorSiloCounter, address(siloFactory), creator_);
        configData1.silo = CloneDeterministic.predictSilo1Addr(_siloImpl, creatorSiloCounter, address(siloFactory), creator_);

        configData0.collateralShareToken = configData0.silo;
        configData1.collateralShareToken = configData1.silo;

        configData0.protectedShareToken = CloneDeterministic.predictShareProtectedCollateralToken0Addr(
            _shareProtectedCollateralTokenImpl, creatorSiloCounter, address(siloFactory), creator_
        );

        configData1.protectedShareToken = CloneDeterministic.predictShareProtectedCollateralToken1Addr(
            _shareProtectedCollateralTokenImpl, creatorSiloCounter, address(siloFactory), creator_
        );

        configData0.debtShareToken =
            CloneDeterministic.predictShareDebtToken0Addr(_shareDebtTokenImpl, creatorSiloCounter, address(siloFactory), creator_);

        configData1.debtShareToken =
            CloneDeterministic.predictShareDebtToken1Addr(_shareDebtTokenImpl, creatorSiloCounter, address(siloFactory), creator_);

        _siloConfig = ISiloConfig(address(new SiloConfig(nextSiloId, configData0, configData1)));
    }

    /*     function _deployOracles() internal {
        oracle0 = address(new MockSiloOracle(address(_asset0), 1 ether, QUOTE_TOKEN_ADDRESS, 18));
        oracle1 = address(new MockSiloOracle(address(_asset1), 1 ether, QUOTE_TOKEN_ADDRESS, 18));
    } */

    function _getInitData(address asset0, address asset1, address liquidationModule)
        internal
        returns (ISiloConfig.InitData memory)
    {
        return ISiloConfig.InitData({
            deployer: deployer_,
            daoFee: 0.15e18,
            deployerFee: 0.1e18,
            token0: asset0,
            solvencyOracle0: oracle0,
            maxLtvOracle0: oracle0,
            interestRateModel0: address(interestRateModelV2),
            maxLtv0: 0.75e18,
            lt0: 0.85e18,
            liquidationTargetLtv0: 0.85e18 * 0.9e18 / 1e18,
            liquidationFee0: 0.05e18,
            flashloanFee0: 0.01e18,
            callBeforeQuote0: false,
            hookReceiver: liquidationModule,
            token1: asset1,
            solvencyOracle1: oracle1,
            maxLtvOracle1: oracle1,
            interestRateModel1: address(interestRateModelV2),
            maxLtv1: 0.85e18,
            lt1: 0.95e18,
            liquidationTargetLtv1: 0.95e18 * 0.9e18 / 1e18,
            liquidationFee1: 0.025e18,
            flashloanFee1: 0.01e18,
            callBeforeQuote1: false
        });
    }
}
