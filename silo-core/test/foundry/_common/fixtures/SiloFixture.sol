// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";

import {StdCheats} from "forge-std/StdCheats.sol";
import {CommonBase} from "forge-std/Base.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {OracleConfig} from "silo-oracles/deploy/OraclesDeployments.sol";
import {VeSiloContracts} from "ve-silo/common/VeSiloContracts.sol";

import {MainnetDeploy} from "silo-core/deploy/MainnetDeploy.s.sol";
import {SiloDeploy} from "silo-core/deploy/silo/SiloDeploy.s.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IPartialLiquidation} from "silo-core/contracts/interfaces/IPartialLiquidation.sol";

import {TokenMock} from "../../_mocks/TokenMock.sol";

struct SiloConfigOverride {
    address token0;
    address token1;
    address solvencyOracle0;
    address maxLtvOracle0;
    string configName;
}

contract SiloDeploy_Local is SiloDeploy {
    SiloConfigOverride internal siloConfigOverride;

    constructor(SiloConfigOverride memory _override) {
        siloConfigOverride = _override;
    }

    function beforeCreateSilo(ISiloConfig.InitData memory _config) internal view override {
        _config.token0 = siloConfigOverride.token0;
        _config.token1 = siloConfigOverride.token1;
        _config.solvencyOracle0 = siloConfigOverride.solvencyOracle0;
        _config.maxLtvOracle0 = siloConfigOverride.maxLtvOracle0;
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
        return _deploy(new SiloDeploy(), SiloConfigsNames.ETH_USDC_UNI_V3_SILO);
    }

    function deploy_local(SiloConfigOverride memory _override)
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
        // Mock addresses that we need for the `SiloFactoryDeploy` script
        AddrLib.setAddress(VeSiloContracts.TIMELOCK_CONTROLLER, makeAddr("Timelock"));
        AddrLib.setAddress(VeSiloContracts.FEE_DISTRIBUTOR, makeAddr("FeeDistributor"));
        console2.log("[SiloFixture] _deploy: setAddress done.");

        return _deploy(
            new SiloDeploy_Local(_override),
            bytes(_override.configName).length == 0 ? SiloConfigsNames.LOCAL_NO_ORACLE_SILO : _override.configName
        );
    }

    function _deploy(SiloDeploy _siloDeploy, string memory _configName)
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
        ) = siloConfig.getConfigs(silo, address(0));

        silo0 = ISilo(siloConfig0.silo);
        silo1 = ISilo(siloConfig1.silo);

        token0 = siloConfig0.token;
        token1 = siloConfig1.token;

        liquidationModule = IPartialLiquidation(siloConfig0.liquidationModule);
        if (address(liquidationModule) == address(0)) revert("liquidationModule is empty");
    }
}
