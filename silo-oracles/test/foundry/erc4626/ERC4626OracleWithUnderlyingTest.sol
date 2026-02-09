// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {ERC4626Mock} from "openzeppelin5/mocks/token/ERC4626Mock.sol";
import {ERC20Mock} from "openzeppelin5/mocks/token/ERC20Mock.sol";

import {ERC4626OracleWithUnderlyingFactoryDeploy} from
    "../../../deploy/erc4626/ERC4626OracleWithUnderlyingFactoryDeploy.s.sol";
import {ERC4626OracleWithUnderlyingDeploy} from "../../../deploy/erc4626/ERC4626OracleWithUnderlyingDeploy.s.sol";
import {ERC4626OracleWithUnderlyingFactory} from
    "silo-oracles/contracts/erc4626/ERC4626OracleWithUnderlyingFactory.sol";
import {ERC4626OracleWithUnderlying} from "silo-oracles/contracts/erc4626/ERC4626OracleWithUnderlying.sol";
import {SiloOraclesFactoriesContracts} from "silo-oracles/deploy/SiloOraclesFactoriesContracts.sol";
import {IERC4626OracleWithUnderlying} from "silo-oracles/contracts/interfaces/IERC4626OracleWithUnderlying.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

/*
    FOUNDRY_PROFILE=oracles forge test --mc ERC4626OracleWithUnderlyingTest --ffi -vv
*/
contract ERC4626OracleWithUnderlyingTest is Test {
    ERC4626OracleWithUnderlying oracle;
    address wstUSR;
    address chainlink;
    address underlying;

    function setUp() public {
        underlying = address(new ERC20Mock());
        wstUSR = address(new ERC4626Mock(underlying));

        AddrLib.init();

        ERC4626OracleWithUnderlyingFactoryDeploy factoryDeployer = new ERC4626OracleWithUnderlyingFactoryDeploy();
        factoryDeployer.disableDeploymentsSync();

        ERC4626OracleWithUnderlyingFactory factory = ERC4626OracleWithUnderlyingFactory(factoryDeployer.run());

        AddrLib.setAddress(SiloOraclesFactoriesContracts.ERC4626_ORACLE_UNDERLYING_FACTORY, address(factory));

        ERC4626OracleWithUnderlyingDeploy deployer = new ERC4626OracleWithUnderlyingDeploy();
        chainlink = makeAddr("CHAINLINK_USR_USD");
        deployer.setUseConfig("wstUSR", "CHAINLINK_USR_USD");

        AddrLib.setAddress("wstUSR", wstUSR);
        AddrLib.setAddress("CHAINLINK_USR_USD", chainlink);

        vm.mockCall(chainlink, abi.encodeWithSelector(ISiloOracle.quoteToken.selector), abi.encode(underlying));

        vm.mockCall(
            chainlink,
            abi.encodeWithSelector(ISiloOracle.quote.selector, 1e18, address(underlying)),
            abi.encode(1.088293604071978577e18)
        );

        oracle = deployer.run();
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
        assertEq(oracle.quote(1e18, AddrLib.getAddress("wstUSR")), 1.088293604071978577e18, "wstUSR price in USD");
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_wrappedVault_BaseAmountOverflow --ffi -vv
     */
    function test_wrappedVault_BaseAmountOverflow() public {
        vm.expectRevert(IERC4626OracleWithUnderlying.BaseAmountOverflow.selector);
        oracle.quote(2 ** 128, address(1));
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_wrappedVault_AssetNotSupported --ffi -vv
     */
    function test_wrappedVault_AssetNotSupported() public {
        vm.expectRevert(IERC4626OracleWithUnderlying.AssetNotSupported.selector);
        oracle.quote(1, address(1));
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_wrappedVault_ZeroQuote --ffi -vv
     */
    function test_wrappedVault_ZeroQuote() public {
        vm.mockCallRevert(
            chainlink,
            abi.encodeWithSelector(ISiloOracle.quote.selector, 0, address(underlying)),
            abi.encodeWithSelector(IERC4626OracleWithUnderlying.ZeroQuote.selector)
        );

        vm.expectRevert(IERC4626OracleWithUnderlying.ZeroQuote.selector);
        oracle.quote(0, wstUSR);
    }
}
