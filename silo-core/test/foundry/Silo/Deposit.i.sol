// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {MainnetDeploy} from "silo-core/deploy/MainnetDeploy.s.sol";
import {SiloDeploy_ETH_USDC_1 as SiloDeploy1} from "silo-core/deploy/silo/SiloDeploy_ETH_USDC_1.s.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {Token} from "silo-core/test/foundry/_mocks/Token.sol";

contract DepositTest is IntegrationTest {
    ISiloConfig siloConfig;
    ISilo silo0;
    ISilo silo1;

    Token weth;
    Token usdc;

    uint256 internal constant _FORKING_BLOCK_NUMBER = 17336000;

    function setUp() public {
        vm.createSelectFork(getChainRpcUrl(MAINNET_ALIAS), _FORKING_BLOCK_NUMBER);

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

        weth = new Token(vm, siloConfig0.token);
        usdc = new Token(vm, siloConfig1.token);
    }

    /*
    forge test -vv --mt test_deposit_gas
    */
    function test_deposit_gas() public {
        uint256 assets = 1e18;
        address receiver = address(10);
        weth.transferFromMock(address(this), address(silo0), assets);
        uint256 gasStart = gasleft();
        uint256 shares = silo0.deposit(assets, receiver, ISilo.AssetType.Collateral);
        uint256 gasEnd = gasleft();

        assertEq(gasStart - gasEnd, 147280, "optimise deposit");
    }
}
