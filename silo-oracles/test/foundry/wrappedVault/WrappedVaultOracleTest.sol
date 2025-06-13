// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {WrappedVaultOracleFactoryDeploy} from "silo-oracles/deploy/wrappedVault/WrappedVaultOracleFactoryDeploy.s.sol";
import {WrappedVaultOracleDeploy} from "silo-oracles/deploy/wrappedVault/WrappedVaultOracleDeploy.s.sol";
import {WrappedVaultOracleFactory} from "silo-oracles/contracts/wrappedVault/WrappedVaultOracleFactory.sol";
import {WrappedVaultOracle} from "silo-oracles/contracts/wrappedVault/WrappedVaultOracle.sol";
import {SiloOraclesFactoriesContracts} from "silo-oracles/deploy/SiloOraclesFactoriesContracts.sol";
import {IWrappedVaultOracle} from "silo-oracles/contracts/interfaces/IWrappedVaultOracle.sol";

/*
    FOUNDRY_PROFILE=oracles forge test --mc WrappedVaultOracleTest --ffi -vv
*/
contract WrappedVaultOracleTest is Test {
    WrappedVaultOracle oracle;
    address wstUSR;

    function setUp() public {
        vm.createSelectFork(vm.envString("RPC_MAINNET"), 22690540); // forking block Jun 12 2025

        AddrLib.init();

        WrappedVaultOracleFactoryDeploy factoryDeployer = new WrappedVaultOracleFactoryDeploy();
        factoryDeployer.disableDeploymentsSync();

        WrappedVaultOracleFactory factory = WrappedVaultOracleFactory(factoryDeployer.run());

        AddrLib.setAddress(SiloOraclesFactoriesContracts.WRAPPED_VAULT_ORACLE_FACTORY, address(factory));

        WrappedVaultOracleDeploy deployer = new WrappedVaultOracleDeploy();
        deployer.setUseConfig("wstUSR", "CHAINLINK_USR_USD");

        oracle = deployer.run();

        wstUSR = AddrLib.getAddress("wstUSR");
    }


    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_wrappedVault_deploy --ffi -vv
     */
    function test_wrappedVault_deploy() public {
        // deploy pass
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_wrappedVault_price --ffi -vv
     */
    function test_wrappedVault_price() public {
        /*
        WstUSR::convertToAssets(1e18) = 1087372222978808737;
        at this block USR price in aggregator is 1.0
        chainlink.quote() => 1087372222978808737
        */
        assertEq(oracle.quote(1e18, AddrLib.getAddress("wstUSR")), 1.087372222978808737e18, "wstUSR price in USD");
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_wrappedVault_BaseAmountOverflow --ffi -vv
     */
    function test_wrappedVault_BaseAmountOverflow() public {
        vm.expectRevert(IWrappedVaultOracle.BaseAmountOverflow.selector);
        oracle.quote(2 ** 128, address(1));
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_wrappedVault_AssetNotSupported --ffi -vv
     */
    function test_wrappedVault_AssetNotSupported() public {
        vm.expectRevert(IWrappedVaultOracle.AssetNotSupported.selector);
        oracle.quote(1, address(1));
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_wrappedVault_ZeroQuote --ffi -vv
     */
    function test_wrappedVault_ZeroQuote() public {
        vm.expectRevert(IWrappedVaultOracle.ZeroQuote.selector);
        oracle.quote(0, wstUSR);
    }
}
