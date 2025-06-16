// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

import {ERC4626OracleWithUnderlyingFactoryDeploy} from "../../../deploy/erc4626/ERC4626OracleWithUnderlyingFactoryDeploy.s.sol";
import {ERC4626OracleWithUnderlyingDeploy} from "../../../deploy/erc4626/ERC4626OracleWithUnderlyingDeploy.s.sol";
import {ERC4626OracleWithUnderlyingFactory} from "silo-oracles/contracts/erc4626/ERC4626OracleWithUnderlyingFactory.sol";
import {ERC4626OracleWithUnderlying} from "silo-oracles/contracts/erc4626/ERC4626OracleWithUnderlying.sol";
import {SiloOraclesFactoriesContracts} from "silo-oracles/deploy/SiloOraclesFactoriesContracts.sol";
import {IERC4626OracleWithUnderlying} from "silo-oracles/contracts/interfaces/IERC4626OracleWithUnderlying.sol";

/*
    FOUNDRY_PROFILE=oracles forge test --mc ERC4626OracleWithUnderlyingFactoryTest --ffi -vv
*/
contract ERC4626OracleWithUnderlyingFactoryTest is Test {
    ERC4626OracleWithUnderlying oracle;
    address wstUSR;
    ERC4626OracleWithUnderlyingDeploy deployer;
    ERC4626OracleWithUnderlyingFactory factory;

    function setUp() public {
        vm.createSelectFork(vm.envString("RPC_MAINNET"), 22690540); // forking block Jun 12 2025

        AddrLib.init();

        ERC4626OracleWithUnderlyingFactoryDeploy factoryDeployer = new ERC4626OracleWithUnderlyingFactoryDeploy();
        factoryDeployer.disableDeploymentsSync();

        factory = ERC4626OracleWithUnderlyingFactory(factoryDeployer.run());

        AddrLib.setAddress(SiloOraclesFactoriesContracts.ERC4626_ORACLE_UNDERLYING_FACTORY, address(factory));

        deployer = new ERC4626OracleWithUnderlyingDeploy();

        wstUSR = AddrLib.getAddress("wstUSR");
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_deploy_wrappedVault_VaultZero --ffi -vv
     */
    function test_deploy_wrappedVault_ZeroAddress() public {
        vm.expectRevert(IERC4626OracleWithUnderlying.ZeroAddress.selector);
        factory.create(IERC4626(address(0)), ISiloOracle(address(0)), bytes32(0));

        vm.expectRevert(IERC4626OracleWithUnderlying.ZeroAddress.selector);
        factory.create(IERC4626(wstUSR), ISiloOracle(address(0)), bytes32(0));
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_deploy_wrappedVault_revertsWhenValutNotMatchOracle --ffi -vv
     */
    function test_deploy_wrappedVault_revertsWhenValutNotMatchOracle() public {
        deployer.setUseConfig("wstUSR", "CHAINLINK_USDC_USD");

        vm.expectRevert(IERC4626OracleWithUnderlying.AssetNotSupported.selector);
        deployer.run();
    }
}
