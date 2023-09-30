// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";

import {MainnetDeploy} from "silo-core/deploy/MainnetDeploy.s.sol";
import {SiloDeploy_ETH_USDC_1 as SiloDeploy1} from "silo-core/deploy/silo/SiloDeploy_ETH_USDC_1.s.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {TokenMock} from "../../_mocks/TokenMock.sol";

contract SiloFixture_ETH_USDC {
    uint256 internal constant _FORKING_BLOCK_NUMBER = 17336000;

    function deploy(Vm _vm)
        external
        returns (ISiloConfig siloConfig, ISilo silo0, ISilo silo1, TokenMock weth, TokenMock usdc)
    {
        MainnetDeploy mainnetDeploy = new MainnetDeploy();
        mainnetDeploy.disableDeploymentsSync();
        mainnetDeploy.run();

        SiloDeploy1 siloDeploy1 = new SiloDeploy1();
        siloDeploy1.disableDeploymentsSync();
        siloConfig = siloDeploy1.run();

        (address silo,) = siloConfig.getSilos();
        (ISiloConfig.ConfigData memory siloConfig0, ISiloConfig.ConfigData memory siloConfig1) = siloConfig.getConfigs(silo);
        silo0 = ISilo(siloConfig0.silo);
        silo1 = ISilo(siloConfig1.silo);

        weth = new TokenMock(_vm, siloConfig0.token);
        usdc = new TokenMock(_vm, siloConfig1.token);
    }
}
