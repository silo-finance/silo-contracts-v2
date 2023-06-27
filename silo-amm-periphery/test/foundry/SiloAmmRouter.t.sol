// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "silo-amm-core/test/foundry/helpers/Fixtures.sol";
import "silo-amm-core/test/foundry/helpers/TestToken.sol";
import "silo-amm-core/contracts/SiloAmmPairFactory.sol";

import "../../contracts/interfaces/ISiloAmmRouterEvents.sol";
import "../../contracts/SiloAmmRouter.sol";


/*
    FOUNDRY_PROFILE=amm-periphery forge test -vv --match-contract SiloAmmRouterTest
*/
contract SiloAmmRouterTest is Test, Fixtures, ISiloAmmRouterEvents {
    address constant SILO = address(0x5170);
    ISiloOracle constant ORACLE_0 = ISiloOracle(address(0));
    ISiloOracle constant ORACLE_1 = ISiloOracle(address(0));
    address constant BRIDGE = address(0);

    address immutable TOKEN_0;
    address immutable TOKEN_1;
    address constant WETH = address(5);

    SiloAmmPairFactory immutable PAIR_FACTORY;
    SiloAmmRouter immutable ROUTER;

    ISiloAmmPair pair;

    constructor() {
        PAIR_FACTORY = new SiloAmmPairFactory();
        ROUTER = new SiloAmmRouter(PAIR_FACTORY, WETH);

        address t1 = address(new TestToken("A"));
        address t2 = address(new TestToken("B"));

        (TOKEN_0, TOKEN_1) = t1 < t2 ? (t1, t2) : (t2, t1);
    }

    function setUp() public {
        pair = ROUTER.createPair(SILO, TOKEN_0, TOKEN_1, ORACLE_0, ORACLE_1, BRIDGE, ammPriceConfig);

        vm.prank(SILO);
        TestToken(TOKEN_0).approve(address(pair), type(uint256).max);
        vm.prank(SILO);
        TestToken(TOKEN_1).approve(address(pair), type(uint256).max);
    }

    function test_SiloAmmRouter_factory() public {
        assertEq(address(ROUTER.factory()), address(ROUTER), "factory => router");
    }

    function test_SiloAmmRouter_allPairsLength() public {
        assertEq(ROUTER.allPairsLength(), 1, "expect 1 pair setup");
    }

    /*
        FOUNDRY_PROFILE=amm-periphery forge test -vv --match-test test_SiloAmmRouter_pairFor
    */
    function test_SiloAmmRouter_pairFor() public {
        assertEq(address(ROUTER.pairFor(TOKEN_0, TOKEN_1, 1e18)), address(0), "zero");

        uint256 gasStart = gasleft();
        address pair1 = address(ROUTER.pairFor(TOKEN_0, TOKEN_1, 0));
        address pair2 = address(ROUTER.pairFor(TOKEN_1, TOKEN_0, 0));
        uint256 gasUsed = gasStart - gasleft();

        assertEq(pair1, address(pair));
        assertEq(pair2, address(pair), "reverse");

        emit log_named_uint("gas used", gasUsed);
        assertEq(gasUsed, 6738);
    }

    /*
        FOUNDRY_PROFILE=amm-periphery forge test -vv --match-test test_SiloAmmRouter_getPairs
    */
    function test_SiloAmmRouter_getPairs() public {
        uint256 gasStart = gasleft();
        IUniswapV2Pair[] memory pairs = ROUTER.getPairs(TOKEN_0, TOKEN_1);
        uint256 gasUsed = gasStart - gasleft();

        emit log_named_uint("gas used", gasUsed);
        assertEq(gasUsed, 9204);

        assertEq(pairs.length, 1);
    }

    /*
        FOUNDRY_PROFILE=amm-periphery forge test -vv --match-test test_SiloAmmRouter_createPair_events
    */
    function test_SiloAmmRouter_createPair_events() public {
        address silo = address(111);
        ISiloAmmPair pair2;
        uint256 pairId = 1;

        // we do not checking topic 3 because pair is unknown atm
        vm.expectEmit(true, true, true, false);
        emit ISiloAmmRouterEvents.PairCreated(TOKEN_0, TOKEN_1, address(0), pairId);

        pair2 = ROUTER.createPair(silo, TOKEN_0, TOKEN_1, ORACLE_0, ORACLE_1, BRIDGE, ammPriceConfig);

        assertEq(address(ROUTER.allPairs(pairId)), address(pair2), "allPairs[]");
    }

    /*
        FOUNDRY_PROFILE=amm-periphery forge test -vv --match-test test_SiloAmmRouter_createPair_gas
    */
    function test_SiloAmmRouter_createPair_gas() public {
        uint256 gasStart = gasleft();
        ROUTER.createPair(SILO, TOKEN_0, TOKEN_1, ORACLE_0, ORACLE_1, BRIDGE, ammPriceConfig);
        uint256 gasUsed = gasStart - gasleft();

        emit log_named_uint("gas used", gasUsed);
        assertEq(gasUsed, 2820272, "gas usage for SiloAmmRouter.createPair");
    }

    /*
        FOUNDRY_PROFILE=amm-periphery forge test -vv --match-test test_SiloAmmRouter_swapExactTokensForTokens_gas
    */
    function test_SiloAmmRouter_swapExactTokensForTokens_gas() public {
        uint256 amountIn = 1e18;
        uint256 amountOutMin = 1e18;

        address[] memory path = _setupForSwap(TOKEN_1, SILO, amountIn, TOKEN_0, amountOutMin);

        address to = address(1111);
        uint256 deadline = block.timestamp;

        uint256 gasStart = gasleft();
        ROUTER.swapExactTokensForTokens(amountIn, amountOutMin, path, to, deadline);
        uint256 gasUsed = gasStart - gasleft();

        emit log_named_uint("gas used", gasUsed);
        assertEq(gasUsed, 124013, "gas usage for SiloAmmRouter.swapExactTokensForTokens");

        assertEq(TestToken(path[0]).balanceOf(SILO), amountIn, "expect silo to got debt");
        assertEq(TestToken(path[0]).balanceOf(to), 0, "expect swapper to not have debt token");
        assertEq(TestToken(path[2]).balanceOf(SILO), 0, "expect silo to not have collateral");
        assertEq(TestToken(path[2]).balanceOf(to), amountOutMin, "expect swapper to got collateral");
    }

    /*
        FOUNDRY_PROFILE=amm-periphery forge test -vv --match-test test_SiloAmmRouter_getAmountsOut_gas
    */
    function test_SiloAmmRouter_getAmountsOut_gas() public {
        uint256 amountIn = 1e18;
        uint256 amountOutMin = 1e18;

        address[] memory path = _setupForSwap(TOKEN_1, SILO, amountIn, TOKEN_0, amountOutMin);

        uint256 gasStart = gasleft();
        uint256[] memory amountsOut = ROUTER.getAmountsOut(amountIn, path);
        uint256 gasUsed = gasStart - gasleft();

        emit log_named_uint("gas used", gasUsed);
        assertEq(gasUsed, 7752, "gas usage for SiloAmmRouter.getAmountsOut");

        assertEq(amountsOut.length, 2, "expect to have 2 amounts");
        assertEq(amountsOut[0], amountIn, "expect amount 0 to be IN");
        assertEq(amountsOut[1], amountOutMin, "expect amount 1 to be OUT");


        uint256 timestamp = block.timestamp + 100;

        gasStart = gasleft();
        amountsOut = ROUTER.getAmountsOut(amountIn, path, timestamp);
        gasUsed = gasStart - gasleft();

        emit log_named_uint("gas used with timestamp", gasUsed);
        assertEq(gasUsed, 5354, "gas usage for SiloAmmRouter.getAmountsOut@timestamp");

        assertEq(amountsOut[0], amountIn, "expect amount 0 to be IN");
        assertEq(amountsOut[1], 1000463177396942966, "expect amount 1 to be OUT");
    }

    /*
        FOUNDRY_PROFILE=amm-periphery forge test -vv --match-test test_SiloAmmRouter_getAmountsIn_gas
    */
    function test_SiloAmmRouter_getAmountsIn_gas() public {
        uint256 amountIn = 1e18;
        uint256 amountOutMin = 1e18;

        address[] memory path = _setupForSwap(TOKEN_1, SILO, amountIn, TOKEN_0, amountOutMin);

        uint256 gasStart = gasleft();
        uint256[] memory amountsIn = ROUTER.getAmountsIn(amountOutMin, path);
        uint256 gasUsed = gasStart - gasleft();

        emit log_named_uint("gas used", gasUsed);
        assertEq(gasUsed, 8054, "gas usage for SiloAmmRouter.getAmountsIn");

        assertEq(amountsIn.length, 2, "expect to have 2 amounts");
        assertEq(amountsIn[0], amountIn, "expect amount 0 to be IN");
        assertEq(amountsIn[1], amountOutMin, "expect amount 1 to be OUT");


        uint256 timestamp = block.timestamp + 100;

        gasStart = gasleft();
        amountsIn = ROUTER.getAmountsIn(amountOutMin, path, timestamp);
        gasUsed = gasStart - gasleft();

        emit log_named_uint("gas used with timestamp", gasUsed);
        assertEq(gasUsed, 5185, "gas usage for SiloAmmRouter.getAmountsIn@timestamp");

        assertEq(amountsIn[0], 999537037037037100, "expect amount 0 to be IN");
        assertEq(amountsIn[1], amountOutMin, "expect amount 1 to be OUT");
    }

    function _setupForSwap(
        address _collateral,
        address _silo,
        uint256 _collateralAmount,
        address _debt,
        uint256 _debtAmount
    )
        internal
        returns (address[] memory path)
    {
        // mint debt
        TestToken(_debt).mint(address(this), _debtAmount);
        TestToken(TOKEN_0).approve(address(ROUTER), type(uint256).max);

        // mint collateral
        TestToken(_collateral).mint(_silo, _collateralAmount);

        address user = address(333);
        bool cleanUp = false;
        uint256 collateralValue = _collateralAmount; // assuming price 1:1

        vm.prank(_silo);
        pair.addLiquidity(_collateral, user, cleanUp, _collateralAmount, collateralValue);

        path = new address[](3);

        path[0] = _debt;
        path[1] = address(pair);
        path[2] = _collateral;
    }
}
