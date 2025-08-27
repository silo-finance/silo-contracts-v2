// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {AggregatorV3Interface} from "chainlink/v0.8/interfaces/AggregatorV3Interface.sol";
import {ERC20} from "openzeppelin5/token/ERC20/ERC20.sol";

import {PTLinearOracleFactory} from "silo-oracles/contracts/pendle/linear/PTLinearOracleFactory.sol";
import {IPTLinearOracleConfig} from "silo-oracles/contracts/interfaces/IPTLinearOracleConfig.sol";
import {IPTLinearOracle} from "silo-oracles/contracts/interfaces/IPTLinearOracle.sol";
import {IPTLinearOracleFactory} from "silo-oracles/contracts/interfaces/IPTLinearOracleFactory.sol";

import {PTLinearMocks} from "./_common/PTLinearMocks.sol";
import {PTLinearOracle} from "silo-oracles/contracts/pendle/linear/PTLinearOracle.sol";

import {SparkLinearDiscountOracleFactoryMock} from "./_common/SparkLinearDiscountOracleFactoryMock.sol";

contract Token is ERC20 {
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {}
}

/*
    FOUNDRY_PROFILE=oracles forge test --mc PTLinearOracleTest --ffi -vv
*/
contract PTLinearOracleTest is PTLinearMocks {
    PTLinearOracleFactory factory;

    function setUp() public {
        factory = new PTLinearOracleFactory(address(new SparkLinearDiscountOracleFactoryMock()));
    }

    // /*
    // FOUNDRY_PROFILE=oracles forge test --mt test_skip_ptamm_PT_USDe_price --ffi -vv
    // */
    // function test_skip_ptamm_PT_USDe_price() public {
    //     vm.createSelectFork(vm.envString("RPC_AVALANCHE"), 67369870);
    //     factory = new PTLinearOracleFactory();

    //     address pt = 0xB4205a645c7e920BD8504181B1D7f2c5C955C3e7;
    //     address usde = 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34; // underlying token of PT

    //     IPTLinearOracleConfig.OracleConfig memory config = IPTLinearOracleConfig.OracleConfig({
    //         amm: IPendleAMM(0x4d717868F4Bd14ac8B29Bb6361901e30Ae05e340),
    //         ptToken: pt,
    //         ptUnderlyingQuoteToken: usde,
    //         hardcoddedQuoteToken: address(1)
    //     });

    //     IPTLinearOracle oracle = factory.create(config, bytes32(0));

    //     assertEq(oracle.quote(1e18, pt), 0.98053159203196347e18, "PT price 1e18");
    //     assertEq(oracle.quote(2e18, pt), 0.98053159203196347e18 * 2 + 1, "PT price 2e18");
    // }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptLinear_Mockprice --ffi -vv
    */
    function test_ptLinear_Mockprice() public {
        IPTLinearOracle oracle = _createOracle();

        _mockLatestRoundData(0.9e18);
        _mockExchangeRate(0.8e18);

        uint256 price = oracle.quote(1e18, makeAddr("ptToken"));

        assertEq(price, 1e18 * 0.9e18 * 0.8e18 / DP / DP, "Mocked PT price");
        assertEq(price, 0.72e18, "Mocked PT price");
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptLinear_description --ffi -vv
    */
    function test_ptLinear_description() public {
        ERC20 pt = new Token("pt token", "PT");
        ERC20 quoteToken = new Token("quote token", "QUOTE");

        IPTLinearOracleFactory.DeploymentConfig memory config;
        config.hardcodedQuoteToken = address(quoteToken);
        config.expectedUnderlyingToken = address(quoteToken);

        _makeValidConfig(config);
        _mockReadTokens(makeAddr("syToken"), address(pt), address(quoteToken));
        _mockExchangeRate(1e18);
        _mockAssetInfo(address(quoteToken));
        _mockExpiry(address(pt), block.timestamp + 1 days);

        AggregatorV3Interface oracle = AggregatorV3Interface(address(factory.create(config, bytes32(0))));

        assertEq(oracle.description(), "PTLinearOracle for PT / QUOTE", "Description should match");
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptLinear_version --ffi -vv
    */
    function test_ptLinear_version() public {
        AggregatorV3Interface oracle = AggregatorV3Interface(address(_createOracle()));
        assertEq(oracle.version(), 1, "Version should match");
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptLinear_decimals --ffi -vv
    */
    function test_ptLinear_decimals() public {
        AggregatorV3Interface oracle = AggregatorV3Interface(address(_createOracle()));
        assertEq(oracle.decimals(), 18, "Decimals should match");
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptLinear_getRoundData --ffi -vv
    */
    function test_ptLinear_getRoundData() public {
        AggregatorV3Interface oracle = AggregatorV3Interface(address(_createOracle()));

        _mockLatestRoundData(0.9e18);
        _mockExchangeRate(0.8e18);

        (
            uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound
        ) = oracle.getRoundData(0);

        assertEq(roundId, 0);
        assertEq(answer, 0);
        assertEq(startedAt, 0);
        assertEq(updatedAt, 0);
        assertEq(answeredInRound, 0);
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptLinear_quote_zeroPrice --ffi -vv
    */
    function test_ptLinear_quote_zeroPrice() public {
        IPTLinearOracle oracle = _createOracle();

        _mockLatestRoundData(0);
        _mockExchangeRate(1);

        vm.expectRevert(abi.encodeWithSelector(IPTLinearOracle.ZeroQuote.selector));
        oracle.quote(1e18, makeAddr("ptToken"));

        // even when non zero, we div by 1e36, so result will be 0
        _mockLatestRoundData(1);
        _mockExchangeRate(1);

        vm.expectRevert(abi.encodeWithSelector(IPTLinearOracle.ZeroQuote.selector));
        oracle.quote(1e18, makeAddr("ptToken"));
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptLinear_quote_AssetNotSupported --ffi -vv
    */
    function test_ptLinear_quote_AssetNotSupported() public {
        IPTLinearOracle oracle = _createOracle();

        vm.expectRevert(abi.encodeWithSelector(IPTLinearOracle.AssetNotSupported.selector));
        oracle.quote(1e18, makeAddr("wrongBaseToken"));
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptLinear_quote_BaseAmountOverflow --ffi -vv
    */
    function test_ptLinear_quote_BaseAmountOverflow() public {
        IPTLinearOracle oracle = _createOracle();

        vm.expectRevert(abi.encodeWithSelector(IPTLinearOracle.BaseAmountOverflow.selector));
        oracle.quote(2 ** 128, makeAddr("ptToken"));
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptLinear_quoteToken --ffi -vv
    */
    function test_ptLinear_quoteToken_fuzz(IPTLinearOracleFactory.DeploymentConfig memory _config)
        public
        assumeValidConfig(_config)
    {
        _doAllNecessaryMockCalls(_config);

        IPTLinearOracle oracle = factory.create(_config, bytes32(0));

        assertEq(oracle.quoteToken(), _config.hardcodedQuoteToken, "Quote token should match");
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptLinear_beforeQuote_doNothing --ffi -vv
    */
    function test_ptLinear_beforeQuote_doNothing(address _baseToken) public {
        IPTLinearOracle oracle = new PTLinearOracle();

        oracle.beforeQuote(_baseToken);
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptLinear_quote_NotInitialized --ffi -vv
    */
    function test_ptLinear_quote_NotInitialized() public {
        IPTLinearOracle oracle = new PTLinearOracle();

        vm.expectRevert(abi.encodeWithSelector(IPTLinearOracle.NotInitialized.selector));
        oracle.quote(1e18, makeAddr("ptToken"));
    }

    function _createOracle(IPTLinearOracleFactory.DeploymentConfig memory _config)
        internal
        returns (IPTLinearOracle oracle)
    {
        _makeValidConfig(_config);
        _doAllNecessaryMockCalls(_config);

        oracle = factory.create(_config, bytes32(0));
    }

    function _createOracle() internal returns (IPTLinearOracle oracle) {
        IPTLinearOracleFactory.DeploymentConfig memory config;
        oracle = _createOracle(config);
    }
}
