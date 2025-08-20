// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {Test} from "forge-std/Test.sol";

import {FixedPricePTAMMOracleFactory} from "silo-oracles/contracts/pendle/amm/FixedPricePTAMMOracleFactory.sol";
import {IFixedPricePTAMMOracleConfig} from "silo-oracles/contracts/interfaces/IFixedPricePTAMMOracleConfig.sol";
import {IFixedPricePTAMMOracle} from "silo-oracles/contracts/interfaces/IFixedPricePTAMMOracle.sol";
import {IPendleAMM} from "silo-oracles/contracts/interfaces/IPendleAMM.sol";
import {FixedPricePTAMMOracle} from "silo-oracles/contracts/pendle/amm/FixedPricePTAMMOracle.sol";

/*
    FOUNDRY_PROFILE=oracles forge test --mc FixedPricePTAMMOracleTest --ffi -vv
*/
contract FixedPricePTAMMOracleTest is Test {
    FixedPricePTAMMOracleFactory factory;

    function setUp() public {
        factory = new FixedPricePTAMMOracleFactory();
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_skip_ptamm_PT_USDe_price --ffi -vv
    */
    function test_skip_ptamm_PT_USDe_price() public {
        vm.createSelectFork(vm.envString("RPC_AVALANCHE"), 67369870);
        factory = new FixedPricePTAMMOracleFactory();

        address pt = 0xB4205a645c7e920BD8504181B1D7f2c5C955C3e7;
        address usde = 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34; // underlying token of PT

        IFixedPricePTAMMOracleConfig.DeploymentConfig memory config = IFixedPricePTAMMOracleConfig.DeploymentConfig({
            amm: IPendleAMM(0x4d717868F4Bd14ac8B29Bb6361901e30Ae05e340),
            ptToken: pt,
            ptUnderlyingQuoteToken: usde
        });

        IFixedPricePTAMMOracle oracle = factory.create(config, bytes32(0));

        assertEq(oracle.quote(1e18, pt), 0.98053159203196347e18, "PT price 1e18");
        assertEq(oracle.quote(2e18, pt), 0.98053159203196347e18 * 2 + 1, "PT price 2e18");
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptamm_PT_USDe_Mockprice --ffi -vv
    */
    function test_ptamm_PT_USDe_Mockprice() public {
        // vm.createSelectFork(vm.envString("RPC_AVALANCHE"), 67369870);
        // factory = new FixedPricePTAMMOracleFactory();

        address pt = 0xB4205a645c7e920BD8504181B1D7f2c5C955C3e7;
        address usde = 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34; // underlying token of PT

        IFixedPricePTAMMOracleConfig.DeploymentConfig memory config = IFixedPricePTAMMOracleConfig.DeploymentConfig({
            amm: IPendleAMM(0x4d717868F4Bd14ac8B29Bb6361901e30Ae05e340),
            ptToken: pt,
            ptUnderlyingQuoteToken: usde
        });

        IFixedPricePTAMMOracle oracle = factory.create(config, bytes32(0));

        vm.mockCall(
            address(config.amm),
            abi.encodeWithSelector(IPendleAMM.previewSwapExactPtForToken.selector),
            abi.encode(0.98053159203196347e18) // price at block 67369870
        );

        uint256 price = oracle.quote(1e18, pt);

        assertEq(price, 0.98053159203196347e18, "Mocked PT price");
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptamm_quote_zeroPrice --ffi -vv
    */
    function test_ptamm_quote_zeroPrice() public {
        IFixedPricePTAMMOracleConfig.DeploymentConfig memory config = IFixedPricePTAMMOracleConfig.DeploymentConfig({
            amm: IPendleAMM(makeAddr("amm")),
            ptToken: makeAddr("ptToken"),
            ptUnderlyingQuoteToken: makeAddr("ptUnderlyingQuoteToken")
        });

        IFixedPricePTAMMOracle oracle = factory.create(config, bytes32(0));

        vm.mockCall(
            address(config.amm), abi.encodeWithSelector(IPendleAMM.previewSwapExactPtForToken.selector), abi.encode(0)
        );

        vm.expectRevert(abi.encodeWithSelector(IFixedPricePTAMMOracle.ZeroQuote.selector));
        oracle.quote(1e18, config.ptToken);
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptamm_quote_AssetNotSupported --ffi -vv
    */
    function test_ptamm_quote_AssetNotSupported() public {
        IFixedPricePTAMMOracleConfig.DeploymentConfig memory config = IFixedPricePTAMMOracleConfig.DeploymentConfig({
            amm: IPendleAMM(makeAddr("amm")),
            ptToken: makeAddr("ptToken"),
            ptUnderlyingQuoteToken: makeAddr("ptUnderlyingQuoteToken")
        });

        IFixedPricePTAMMOracle oracle = factory.create(config, bytes32(0));

        vm.expectRevert(abi.encodeWithSelector(IFixedPricePTAMMOracle.AssetNotSupported.selector));
        oracle.quote(1e18, makeAddr("wrongBaseToken"));
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptamm_quote_BaseAmountOverflow --ffi -vv
    */
    function test_ptamm_quote_BaseAmountOverflow() public {
        IFixedPricePTAMMOracleConfig.DeploymentConfig memory config = IFixedPricePTAMMOracleConfig.DeploymentConfig({
            amm: IPendleAMM(makeAddr("amm")),
            ptToken: makeAddr("ptToken"),
            ptUnderlyingQuoteToken: makeAddr("ptUnderlyingQuoteToken")
        });

        IFixedPricePTAMMOracle oracle = factory.create(config, bytes32(0));

        vm.expectRevert(abi.encodeWithSelector(IFixedPricePTAMMOracle.BaseAmountOverflow.selector));
        oracle.quote(2 ** 128, config.ptToken);
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptamm_quoteToken --ffi -vv
    */
    function test_ptamm_quoteToken_fuzz(IFixedPricePTAMMOracleConfig.DeploymentConfig memory _config) public {
        vm.assume(_config.ptUnderlyingQuoteToken != address(0));
        vm.assume(_config.ptToken != address(0));
        vm.assume(_config.ptUnderlyingQuoteToken != _config.ptToken);

        IFixedPricePTAMMOracle oracle = factory.create(_config, bytes32(0));

        assertEq(oracle.quoteToken(), _config.ptUnderlyingQuoteToken);
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptamm_beforeQuote_doNothing --ffi -vv
    */
    function test_ptamm_beforeQuote_doNothing(address _baseToken) public {
        FixedPricePTAMMOracle oracle = new FixedPricePTAMMOracle();

        oracle.beforeQuote(_baseToken);
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptamm_quote_NotInitialized --ffi -vv
    */
    function test_ptamm_quote_NotInitialized() public {
        FixedPricePTAMMOracle oracle = new FixedPricePTAMMOracle();

        vm.expectRevert(abi.encodeWithSelector(IFixedPricePTAMMOracle.NotInitialized.selector));
        oracle.quote(1e18, makeAddr("ptToken"));
    }
}
