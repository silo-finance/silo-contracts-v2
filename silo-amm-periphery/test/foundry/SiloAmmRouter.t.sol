// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "silo-amm-core/test/foundry/helpers/Fixtures.sol";
import "silo-amm-core/contracts/SiloAmmPairFactory.sol";

import "../../contracts/SiloAmmRouter.sol";
import "../../contracts/interfaces/ISiloAmmRouterEvents.sol";


/*
    FOUNDRY_PROFILE=amm-periphery forge test -vv --match-contract SiloAmmRouterTest
*/
contract SiloAmmRouterTest is Test, Fixtures, ISiloAmmRouterEvents {
    ISiloOracle constant ORACLE_0 = ISiloOracle(address(0));
    ISiloOracle constant ORACLE_1 = ISiloOracle(address(0));

    address constant TOKEN_0 = address(3);
    address constant TOKEN_1 = address(4);
    address constant WETH = address(5);

    SiloAmmPairFactory immutable PAIR_FACTORY;
    SiloAmmRouter immutable ROUTER;

    ISiloAmmPair pair;

    constructor() {
        PAIR_FACTORY = new SiloAmmPairFactory();
        ROUTER = new SiloAmmRouter(PAIR_FACTORY, WETH);
    }

    function setUp() public {
        pair = ROUTER.createPair(address(this), TOKEN_0, TOKEN_1, ORACLE_0, ORACLE_1, ammPriceConfig);
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
        assertEq(gasUsed, 6723);
    }

    /*
        FOUNDRY_PROFILE=amm-periphery forge test -vv --match-test test_SiloAmmRouter_getPairs
    */
    function test_SiloAmmRouter_getPairs() public {
        uint256 gasStart = gasleft();
        IUniswapV2Pair[] memory pairs = ROUTER.getPairs(TOKEN_0, TOKEN_1);
        uint256 gasUsed = gasStart - gasleft();

        emit log_named_uint("gas used", gasUsed);
        assertEq(gasUsed, 9169);

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

        pair2 = ROUTER.createPair(silo, TOKEN_0, TOKEN_1, ORACLE_0, ORACLE_1, ammPriceConfig);

        assertEq(address(ROUTER.allPairs(pairId)), address(pair2), "allPairs[]");
    }

    /*
        FOUNDRY_PROFILE=amm-periphery forge test -vv --match-test test_SiloAmmRouter_createPair_gas
    */
    function test_SiloAmmRouter_createPair_gas() public {
        uint256 gasStart = gasleft();
        ROUTER.createPair(address(123), TOKEN_0, TOKEN_1, ORACLE_0, ORACLE_1, ammPriceConfig);
        uint256 gasUsed = gasStart - gasleft();

        emit log_named_uint("gas used", gasUsed);
        assertEq(gasUsed, 2472114, "gas usage for SiloAmmRouter.createPair");
    }
}
