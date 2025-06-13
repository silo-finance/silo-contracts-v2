// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

import {WrappedVaultOracleFactoryDeploy} from "silo-oracles/deploy/wrappedVault/WrappedVaultOracleFactoryDeploy.s.sol";
import {WrappedVaultOracleDeploy} from "silo-oracles/deploy/wrappedVault/WrappedVaultOracleDeploy.s.sol";
import {WrappedVaultOracleFactory} from "silo-oracles/contracts/wrappedVault/WrappedVaultOracleFactory.sol";
import {WrappedVaultOracle} from "silo-oracles/contracts/wrappedVault/WrappedVaultOracle.sol";
import {SiloOraclesFactoriesContracts} from "silo-oracles/deploy/SiloOraclesFactoriesContracts.sol";
import {IWrappedVaultOracle} from "silo-oracles/contracts/interfaces/IWrappedVaultOracle.sol";

/*
    FOUNDRY_PROFILE=oracles forge test --mc WrappedVaultOracleFactoryTest --ffi -vv
*/
contract WrappedVaultOracleFactoryTest is Test {
    WrappedVaultOracle oracle;
    address wstUSR;
    WrappedVaultOracleDeploy deployer;
    WrappedVaultOracleFactory factory;

    function setUp() public {
        vm.createSelectFork(vm.envString("RPC_MAINNET"), 22690540); // forking block Jun 12 2025

        AddrLib.init();

        WrappedVaultOracleFactoryDeploy factoryDeployer = new WrappedVaultOracleFactoryDeploy();
        factoryDeployer.disableDeploymentsSync();

        factory = WrappedVaultOracleFactory(factoryDeployer.run());

        AddrLib.setAddress(SiloOraclesFactoriesContracts.WRAPPED_VAULT_ORACLE_FACTORY, address(factory));

        deployer = new WrappedVaultOracleDeploy();

        wstUSR = AddrLib.getAddress("wstUSR");
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_deploy_wrappedVault_VaultZero --ffi -vv
     */
    function test_deploy_wrappedVault_ZeroAddress() public {
        vm.expectRevert(IWrappedVaultOracle.ZeroAddress.selector);
        factory.create(IERC4626(address(0)), ISiloOracle(address(0)), bytes32(0));

        vm.expectRevert(IWrappedVaultOracle.ZeroAddress.selector);
        factory.create(IERC4626(wstUSR), ISiloOracle(address(0)), bytes32(0));
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_deploy_wrappedVault_revertsWhenValutNotMatchOracle --ffi -vv
     */
    function test_deploy_wrappedVault_revertsWhenValutNotMatchOracle() public {
        deployer.setUseConfig("wstUSR", "CHAINLINK_USDC_USD");

        vm.expectRevert(IWrappedVaultOracle.AssetNotSupported.selector);
        deployer.run();
    }
}
