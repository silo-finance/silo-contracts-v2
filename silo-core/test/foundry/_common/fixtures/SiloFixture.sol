// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {console2} from "forge-std/console2.sol";

import {StdCheats} from "forge-std/StdCheats.sol";
import {CommonBase} from "forge-std/Base.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {OracleConfig} from "silo-oracles/deploy/OraclesDeployments.sol";

import {MainnetDeploy} from "silo-core/deploy/MainnetDeploy.s.sol";
import {SiloDeployWithGaugeHookReceiver} from "silo-core/deploy/silo/SiloDeployWithGaugeHookReceiver.s.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IPartialLiquidation} from "silo-core/contracts/interfaces/IPartialLiquidation.sol";

import {VeSiloContracts} from "ve-silo/common/VeSiloContracts.sol";

import {TokenMock} from "../../_mocks/TokenMock.sol";

import {console} from "forge-std/console.sol";

struct SiloConfigOverride {
    address token0;
    address token1;
    address hookReceiver;
    address solvencyOracle0;
    address maxLtvOracle0;
    string configName;
}

contract SiloDeploy_Local is SiloDeployWithGaugeHookReceiver {
    bytes32 public constant NO_HOOK_RECEIVER_KEY = keccak256(bytes("NO_HOOK_RECEIVER"));

    SiloConfigOverride internal siloConfigOverride;

    error SiliFixtureHookReceiverImplNotFound(string hookReceiver);

    constructor(SiloConfigOverride memory _override) {
        siloConfigOverride = _override;
    }

    function beforeCreateSilo(
        ISiloConfig.InitData memory _config
    ) internal view override {
        // Override the default values if overrides are provided
        if (siloConfigOverride.token0 != address(0)) {
            _config.token0 = siloConfigOverride.token0;
        }

        if (siloConfigOverride.token1 != address(0)) {
            _config.token1 = siloConfigOverride.token1;
        }

        if (siloConfigOverride.solvencyOracle0 != address(0)) {
            _config.solvencyOracle0 = siloConfigOverride.solvencyOracle0;
        }

        if (siloConfigOverride.maxLtvOracle0 != address(0)) {
            _config.maxLtvOracle0 = siloConfigOverride.maxLtvOracle0;
        }

        if(siloConfigOverride.hookReceiver != address(0)) {
            _config.hookReceiver = siloConfigOverride.hookReceiver;
        }
    }
}

contract SiloFixture is StdCheats, CommonBase {
    uint256 internal constant _FORKING_BLOCK_NUMBER = 17336000;

    function deploy_ETH_USDC()
        external
        returns (
            ISiloConfig siloConfig,
            ISilo silo0,
            ISilo silo1,
            address weth,
            address usdc,
            IPartialLiquidation liquidationModule
        )
    {
        return _deploy(new SiloDeployWithGaugeHookReceiver(), SiloConfigsNames.ETH_USDC_UNI_V3_SILO);
    }

    function deploy_local(string memory _configName)
        external
        returns (
            ISiloConfig siloConfig,
            ISilo silo0,
            ISilo silo1,
            address token0,
            address token1,
            IPartialLiquidation liquidationModule
        )
    {
        SiloConfigOverride memory overrideArgs;
        return _deploy(new SiloDeploy_Local(overrideArgs), _configName);
    }

    function deploy_local(SiloConfigOverride memory _override)
        external
        returns (
            ISiloConfig siloConfig,
            ISilo silo0,
            ISilo silo1,
            address token0,
            address token1,
            IPartialLiquidation liquidationModule
        )
    {
        return _deploy(
            new SiloDeploy_Local(_override),
            bytes(_override.configName).length == 0 ? SiloConfigsNames.LOCAL_NO_ORACLE_SILO : _override.configName
        );
    }

    function _deploy(SiloDeployWithGaugeHookReceiver _siloDeploy, string memory _configName)
        internal
        returns (
            ISiloConfig siloConfig,
            ISilo silo0,
            ISilo silo1,
            address token0,
            address token1,
            IPartialLiquidation liquidationModule
        )
    {
        // TODO: remove dependency on VeSiloContracts
        AddrLib.setAddress(VeSiloContracts.FEE_DISTRIBUTOR, makeAddr("FeeDistributor"));

        MainnetDeploy mainnetDeploy = new MainnetDeploy();
        mainnetDeploy.disableDeploymentsSync();
        mainnetDeploy.run();
        console2.log("[SiloFixture] _deploy: mainnetDeploy.run() done.");

        siloConfig = _siloDeploy.useConfig(_configName).run();
        console2.log("[SiloFixture] _deploy: _siloDeploy(", _configName, ").run() done.");

        (address silo,) = siloConfig.getSilos();

        (
            ISiloConfig.ConfigData memory siloConfig0,
            ISiloConfig.ConfigData memory siloConfig1,
        ) = siloConfig.getConfigs(silo, address(0), 0 /* always 0 for external calls */);

        silo0 = ISilo(siloConfig0.silo);
        silo1 = ISilo(siloConfig1.silo);

        token0 = siloConfig0.token;
        token1 = siloConfig1.token;

        liquidationModule = IPartialLiquidation(siloConfig0.liquidationModule);
        if (address(liquidationModule) == address(0)) revert("liquidationModule is empty");
    }
}
