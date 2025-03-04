// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {TestERC20} from "silo-core/test/invariants/utils/mocks/TestERC20.sol";
import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";
import {PendlePTOracle} from "silo-oracles/contracts/pendle/PendlePTOracle.sol";
import {IPendlePTOracleFactory} from "silo-oracles/contracts/interfaces/IPendlePTOracleFactory.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {PendlePTOracleFactory} from "silo-oracles/contracts/pendle/PendlePTOracleFactory.sol";
import {PendlePTOracle} from "silo-oracles/contracts/pendle/PendlePTOracle.sol";
import {PendlePTOracleDeploy} from "silo-oracles/deploy/pendle/PendlePTOracleDeploy.s.sol";
import {Forking} from "silo-oracles/test/foundry/_common/Forking.sol";
import {IPyYtLpOracleLike} from "silo-oracles/contracts/pendle/interfaces/IPyYtLpOracleLike.sol";
import {SiloOracleMock1} from "silo-oracles/test/foundry/_mocks/silo-oracles/SiloOracleMock1.sol";

/*
    FOUNDRY_PROFILE=oracles forge test -vv --match-contract PendlePTOracleTest --ffi
*/
contract PendlePTOracleTest is Forking {
    PendlePTOracleFactory factory;
    PendlePTOracle oracle;
    IPyYtLpOracleLike pendleOracle = IPyYtLpOracleLike(0x9a9Fa8338dd5E5B2188006f1Cd2Ef26d921650C2);
    ISiloOracle underlyingOracle;

    address market = 0x6e4e95FaB7db1f0524b4b0a05F0b9c96380b7Dfa;
    address ptUnderlyingToken = 0x9fb76f7ce5FCeAA2C42887ff441D46095E494206;
    address ptToken = 0xBe27993204Ec64238F71A527B4c4D5F4949034C3;

    event PendlePTOracleCreated(ISiloOracle indexed pendlePTOracle);

    constructor() Forking(BlockChain.SONIC) {
        initFork(11647989); // 1 PT -> 0.9668 underlying
    }

    function setUp() public {
        AddrLib.init();

        factory = new PendlePTOracleFactory(pendleOracle);
        PendlePTOracleDeploy oracleDeploy = new PendlePTOracleDeploy();
        underlyingOracle = new SiloOracleMock1();

        oracle = PendlePTOracle(address(oracleDeploy.deploy({
            _factory: factory,
            _underlyingOracle: underlyingOracle,
            _market: market
        })));
    }

    function test_PendlePTOracle_factory_pendleOracle() public view {
        assertEq(address(factory.PENDLE_ORACLE()), address(pendleOracle), "pendle oracle is set right");
    }

    function test_PendlePTOracle_factory_constructorReverts() public {
        vm.expectRevert(PendlePTOracleFactory.PendleOracleIsZero.selector);
        new PendlePTOracleFactory(IPyYtLpOracleLike(address(0)));
    }

    function test_PendlePTOracle_factory_create_emitsEvent() public {
        vm.expectEmit(false, false, false, false);
        emit PendlePTOracleCreated(ISiloOracle(address(0)));

        factory.create(new SiloOracleMock1(), market);
    }

    function test_PendlePTOracle_factory_create_updatesMapping() public {
        assertTrue(factory.createdInFactory(factory.create(new SiloOracleMock1(), market)));
        assertTrue(factory.createdInFactory(oracle));
    }

    function test_PendlePTOracle_factory_create_canDeployDuplicates() public {
        assertTrue(factory.createdInFactory(factory.create(underlyingOracle, market)));
        assertTrue(factory.createdInFactory(factory.create(underlyingOracle, market)));
    }

    function test_PendlePTOracle_constructor_state() public view {
        assertEq(oracle.RATE_PRECISION_DECIMALS(), 10 ** 18);
        assertEq(oracle.TWAP_DURATION(), 1800);
        assertEq(oracle.PT_TOKEN(), ptToken);
        assertEq(oracle.PT_UNDERLYING_TOKEN(), ptUnderlyingToken);
        assertEq(oracle.MARKET(), market);
        assertEq(address(oracle.UNDERLYING_ORACLE()), address(underlyingOracle));
        assertEq(address(oracle.PENDLE_ORACLE()), address(pendleOracle));
        assertEq(address(oracle.PENDLE_ORACLE()), address(factory.PENDLE_ORACLE()));
        assertEq(oracle.QUOTE_TOKEN(), underlyingOracle.quoteToken());
        assertTrue(oracle.QUOTE_TOKEN() != address(0));
    }

    function test_PendlePTOracle_constructor_revertsInvalidDecimals() public {
        vm.mockCall(
            address(ptUnderlyingToken),
            abi.encodeWithSelector(IERC20Metadata.decimals.selector),
            abi.encode(uint8(63))
        );

        vm.expectRevert(PendlePTOracle.TokensDecimalsDoesNotMatch.selector);
        factory.create(underlyingOracle, market);
    }

    function test_PendlePTOracle_constructor_revertsInvalidUnderlyingOracle() public {
        vm.mockCall(
            address(underlyingOracle),
            abi.encodeWithSelector(ISiloOracle.quote.selector),
            abi.encode(uint256(0))
        );

        vm.expectRevert(PendlePTOracle.InvalidUnderlyingOracle.selector);
        factory.create(underlyingOracle, market);
    }

    function test_PendlePTOracle_constructor_revertsPendleOracleNotReady_cardinality() public {
        vm.mockCall(
            address(pendleOracle),
            abi.encodeWithSelector(IPyYtLpOracleLike.getOracleState.selector),
            abi.encode(true, 0, true) // increaseCardinalityRequired and oldestObservationSatisfied
        );

        vm.expectRevert(PendlePTOracle.PendleOracleNotReady.selector);
        factory.create(underlyingOracle, market);
    }

    function test_PendlePTOracle_constructor_revertsPendleOracleNotReady_observations() public {
        vm.mockCall(
            address(pendleOracle),
            abi.encodeWithSelector(IPyYtLpOracleLike.getOracleState.selector),
            abi.encode(false, 0, false) // increaseCardinalityRequired and oldestObservationSatisfied
        );

        vm.expectRevert(PendlePTOracle.PendleOracleNotReady.selector);
        factory.create(underlyingOracle, market);
    }

    function test_PendlePTOracle_constructor_revertsPendleOracleNotReady_cardinalityAndObservations() public {
        vm.mockCall(
            address(pendleOracle),
            abi.encodeWithSelector(IPyYtLpOracleLike.getOracleState.selector),
            abi.encode(true, 0, false) // increaseCardinalityRequired and oldestObservationSatisfied
        );

        vm.expectRevert(PendlePTOracle.PendleOracleNotReady.selector);
        factory.create(underlyingOracle, market);
    }

    function test_PendlePTOracle_constructor_revertsPendleOracleNotReady_integration() public {
        uint256 blockBeforeCardinalityIncrease = 11636735;
        initFork(blockBeforeCardinalityIncrease);
        assertEq(block.number, blockBeforeCardinalityIncrease);

        factory = new PendlePTOracleFactory(pendleOracle);
        vm.expectRevert(PendlePTOracle.PendleOracleNotReady.selector);
        factory.create(underlyingOracle, market);
    }

    function test_PendlePTOracle_constructor_revertsPendlePtToSyRateIsZero() public {
        vm.mockCall(
            address(pendleOracle),
            abi.encodeWithSelector(IPyYtLpOracleLike.getPtToSyRate.selector),
            abi.encode(0)
        );

        vm.expectRevert(PendlePTOracle.PendlePtToSyRateIsZero.selector);
        factory.create(underlyingOracle, market);
    }

    function test_PendlePTOracle_quoteToken() public view {
        assertEq(oracle.quoteToken(), oracle.QUOTE_TOKEN());
    }

    function test_PendlePTOracle_getPtToken() public view {
        assertEq(oracle.getPtToken(market), ptToken);
    }

    function test_PendlePTOracle_getPtUnderlyingToken() public view {
        assertEq(oracle.getPtUnderlyingToken(market), ptUnderlyingToken);
    }

    function test_PendlePTOracle_beforeQuote_doesNotRevert() public {
        oracle.beforeQuote(address(0));
    }

    function test_PendlePTOracle_quote_revertsAssetNotSupported() public {
        vm.expectRevert(PendlePTOracle.AssetNotSupported.selector);
        oracle.quote(0, ptUnderlyingToken);
    }

    function test_PendlePTOracle_quote() public {
        uint256 quoteAmount = 1000 * IERC20Metadata(ptToken).decimals();
        uint256 quote = oracle.quote(quoteAmount, ptToken);
        uint256 rateFromPendleOracle = IPyYtLpOracleLike(pendleOracle).getPtToSyRate(market, 1800);

        assertEq(underlyingOracle.quote(0, address(0)), 10 ** 18, "underlying oracle always returns 10**18");
        assertEq(underlyingOracle.quote(quoteAmount, ptUnderlyingToken), 10 ** 18, "underlying oracle returns 10**18");
        
        assertEq(
            quote,
            rateFromPendleOracle,
            "quote value is equal to ptToSyRate, because underlying oracle returns 10**18"
        );

        assertTrue(rateFromPendleOracle < 10 ** 18);
        assertEq(rateFromPendleOracle, 967114134407545484); // 0.9671141344, close to UI 0.9668

        uint256 newUnderlyingPrice = 15 * 10 ** 18;

        vm.mockCall(
            address(underlyingOracle),
            abi.encodeWithSelector(ISiloOracle.quote.selector, quoteAmount, ptUnderlyingToken),
            abi.encode(newUnderlyingPrice)
        );

        assertEq(underlyingOracle.quote(0, address(0)), 10 ** 18, "price NOT changed for other tokens");
        assertEq(underlyingOracle.quote(1, ptToken), 10 ** 18, "price NOT changed for other tokens");

        assertEq(
            underlyingOracle.quote(quoteAmount, ptUnderlyingToken),
            newUnderlyingPrice,
            "price changed only for underlying to ensure PT oracle asking underlying price"
        );

        assertEq(oracle.quote(quoteAmount, ptToken), newUnderlyingPrice * rateFromPendleOracle / 10 ** 18);
        assertTrue(oracle.quote(quoteAmount, ptToken) < newUnderlyingPrice);
        assertTrue(oracle.quote(quoteAmount, ptToken) > newUnderlyingPrice * 95 / 100); // rate is ~96.68%
    }
}
