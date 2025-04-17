// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

// ve-silo
import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";
import {ISiloGovernor} from "ve-silo/contracts/governance/interfaces/ISiloGovernor.sol";
import {IVeSilo} from "ve-silo/contracts/voting-escrow/interfaces/IVeSilo.sol";
import {ISmartWalletChecker} from "ve-silo/contracts/voting-escrow/interfaces/ISmartWalletChecker.sol";
import {ISiloTimelockController} from "ve-silo/contracts/governance/interfaces/ISiloTimelockController.sol";
import {ILiquidityGaugeFactory} from "ve-silo/contracts/gauges/interfaces/ILiquidityGaugeFactory.sol";
import {IGaugeController} from "ve-silo/contracts/gauges/interfaces/IGaugeController.sol";
import {IBalancerTokenAdmin} from "ve-silo/contracts/silo-tokens-minter/interfaces/IBalancerTokenAdmin.sol";
import {IBalancerMinter} from "ve-silo/contracts/silo-tokens-minter/interfaces/IBalancerMinter.sol";
import {IGaugeAdder} from "ve-silo/contracts/gauges/interfaces/IGaugeAdder.sol";
import {IMainnetBalancerMinter} from "ve-silo/contracts/silo-tokens-minter/interfaces/IMainnetBalancerMinter.sol";
// silo-core
import {SiloCoreContracts, SiloCoreDeployments} from "silo-core/common/SiloCoreContracts.sol";
import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";
import {IGaugeHookReceiver} from "silo-core/contracts/interfaces/IGaugeHookReceiver.sol";
import {IInterestRateModelV2} from "silo-core/contracts/interfaces/IInterestRateModelV2.sol";
import {IInterestRateModelV2Factory} from "silo-core/contracts/interfaces/IInterestRateModelV2Factory.sol";
// silo-oracles
import {
    SiloOraclesFactoriesContracts,
    SiloOraclesFactoriesDeployments
} from "silo-oracles/deploy/SiloOraclesFactoriesContracts.sol";
import {ChainlinkV3OracleFactory} from "silo-oracles/contracts/chainlinkV3/ChainlinkV3OracleFactory.sol";
import {DIAOracleFactory} from "silo-oracles/contracts/dia/DIAOracleFactory.sol";

// solhint-disable max-states-count

contract SiloContracts {
    // ve-silo
    IBalancerMinter public minter;
    IGaugeController public gaugeController;
    IBalancerTokenAdmin public balancerTokenAdmin;
    ILiquidityGaugeFactory public factory;
    IVeSilo public veSilo;
    ISiloTimelockController public timelock;
    ISiloGovernor public siloGovernor;
    IGaugeAdder public gaugeAdder;
    ISmartWalletChecker public smartWalletChecker;
    IMainnetBalancerMinter public mainnetMinter;
    // silo-core
    IGaugeHookReceiver public gaugeHookReceiver;
    IInterestRateModelV2 public interestRateModelV2;
    IInterestRateModelV2Factory public interestRateModelV2ConfigFactory;
    ISiloFactory public siloFactory;
    // silo-oracles
    ChainlinkV3OracleFactory public chainlinkV3OracleFactory;
    DIAOracleFactory public diaOracleFactory;

    constructor() {
        _veSiloSetUp();
        _siloOraclesSetUp();
        _siloCoreSetUp();
    }

    function _veSiloSetUp() internal {
        string memory chainAlias = ChainsLib.chainAlias();

        // ve-silo related smart contracts
        veSilo = IVeSilo(VeSiloDeployments.get(VeSiloContracts.VOTING_ESCROW, chainAlias));
        timelock = ISiloTimelockController(VeSiloDeployments.get(VeSiloContracts.TIMELOCK_CONTROLLER, chainAlias));
        factory = ILiquidityGaugeFactory(VeSiloDeployments.get(VeSiloContracts.LIQUIDITY_GAUGE_FACTORY, chainAlias));
        gaugeController = IGaugeController(VeSiloDeployments.get(VeSiloContracts.GAUGE_CONTROLLER, chainAlias));
        siloGovernor = ISiloGovernor(VeSiloDeployments.get(VeSiloContracts.SILO_GOVERNOR, chainAlias));
        minter = IBalancerMinter(VeSiloDeployments.get(VeSiloContracts.MAINNET_BALANCER_MINTER, chainAlias));
        gaugeAdder = IGaugeAdder(VeSiloDeployments.get(VeSiloContracts.GAUGE_ADDER, chainAlias));

        mainnetMinter = IMainnetBalancerMinter(
            VeSiloDeployments.get(VeSiloContracts.MAINNET_BALANCER_MINTER, chainAlias)
        );

        smartWalletChecker = ISmartWalletChecker(
            VeSiloDeployments.get(VeSiloContracts.SMART_WALLET_CHECKER, chainAlias)
        );

        balancerTokenAdmin = IBalancerTokenAdmin(
            VeSiloDeployments.get(VeSiloContracts.BALANCER_TOKEN_ADMIN, chainAlias)
        );
    }

    function _siloCoreSetUp() internal {
        string memory chainAlias = ChainsLib.chainAlias();

        gaugeHookReceiver = IGaugeHookReceiver(SiloCoreDeployments.get(SiloCoreContracts.SILO_HOOK_V1, chainAlias));
        siloFactory = ISiloFactory(SiloCoreDeployments.get(SiloCoreContracts.SILO_FACTORY, chainAlias));

        interestRateModelV2ConfigFactory = IInterestRateModelV2Factory(
            SiloCoreDeployments.get(
                SiloCoreContracts.INTEREST_RATE_MODEL_V2_FACTORY,
                chainAlias
            )
        );

        interestRateModelV2 = IInterestRateModelV2(
            SiloCoreDeployments.get(SiloCoreContracts.INTEREST_RATE_MODEL_V2, chainAlias)
        );
    }

    function _siloOraclesSetUp() internal {
        string memory chainAlias = ChainsLib.chainAlias();

        chainlinkV3OracleFactory = ChainlinkV3OracleFactory(
            SiloOraclesFactoriesDeployments.get(
                SiloOraclesFactoriesContracts.CHAINLINK_V3_ORACLE_FACTORY,
                chainAlias
            )
        );

        diaOracleFactory = DIAOracleFactory(
            SiloOraclesFactoriesDeployments.get(
                SiloOraclesFactoriesContracts.DIA_ORACLE_FACTORY,
                chainAlias
            )
        );
    }
}
