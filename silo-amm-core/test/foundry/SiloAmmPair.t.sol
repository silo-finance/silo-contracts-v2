// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "../../contracts/SiloAmmPair.sol";
import "./helpers/Fixtures.sol";


/*
    FOUNDRY_PROFILE=amm-core forge test -vv --match-contract SiloAmmPairTest
*/
contract SiloAmmPairTest is Test, Fixtures {
    bool constant CLEAN_UP = false;
    address constant TOKEN_0 = address(3);
    address constant TOKEN_1 = address(4);

    SiloAmmPair immutable pair;

    constructor() {
        address router = address(1);
        ISiloOracle oracle0;
        ISiloOracle oracle1;

        pair = new SiloAmmPair(router, address(this), TOKEN_0, TOKEN_1, oracle0, oracle1, ammPriceConfig);
    }

    /*
        FOUNDRY_PROFILE=amm-core forge test -vv --match-test test_SiloAmmPair_getReserves_init
    */
    function test_SiloAmmPair_getReserves_init() public {
        uint256 gasStart = gasleft();
        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = pair.getReserves();
        uint256 gasEnd = gasleft();

        uint256 gas = gasStart - gasEnd;
        emit log_named_uint("gas", gas);

        assertEq(gas, 7854);

        assertEq(reserve0, 0);
        assertEq(reserve1, 0);
        assertEq(blockTimestampLast, 0);
    }

    /*
        FOUNDRY_PROFILE=amm-core forge test -vv --match-test test_SiloAmmPair_getOraclePrice_init
    */
    function test_SiloAmmPair_getOraclePrice_init() public {
        uint256 gasStart = gasleft();
        uint256 debtPrice = pair.getOraclePrice(TOKEN_0, 1e18);
        uint256 gasEnd = gasleft();

        uint256 gas = gasStart - gasEnd;
        emit log_named_uint("gas", gas);

        assertEq(gas, 3490);

        assertEq(debtPrice, 0);
    }

    /*
        FOUNDRY_PROFILE=amm-core forge test -vv --match-test test_SiloAmmPair_addLiquidity_onlySilo
    */
    function test_SiloAmmPair_addLiquidity_onlySilo() public {
        vm.prank(address(123));
        vm.expectRevert(ISiloAmmPair.ONLY_SILO.selector);
        pair.addLiquidity(TOKEN_0, address(333), CLEAN_UP, 1e18, 2e18);
    }

    /*
        FOUNDRY_PROFILE=amm-core forge test -vv --match-test test_SiloAmmPair_addLiquidity_gas
    */
    function test_SiloAmmPair_addLiquidity_gas() public {
        address _user = address(333);
        uint256 amount = 1e18;
        uint256 value = 2e18;

        uint256 gasStart = gasleft();
        uint256 shares = pair.addLiquidity(TOKEN_0, _user, CLEAN_UP, amount, value);
        uint256 gas = gasStart - gasleft();

        emit log_named_uint("gas #1", gas);

        assertEq(gas, 204498);
        assertEq(shares, amount, "initial amount == shares");

        gasStart = gasleft();
        uint256 shares2 = pair.addLiquidity(TOKEN_0, _user, true, amount, value);
        gas = gasStart - gasleft();

        emit log_named_uint("gas #2", gas);

        assertEq(gas, 170163, "add with cleanup");
        assertEq(shares, shares2, "expect same shares");
    }

    /*
        FOUNDRY_PROFILE=amm-core forge test -vv --match-test test_SiloAmmPair_removeLiquidity_gas
    */
    function test_SiloAmmPair_removeLiquidity_gas() public {
        address _user = address(333);
        uint256 amount = 1e18;
        uint256 value = 2e18;

        pair.addLiquidity(TOKEN_0, _user, CLEAN_UP, amount, value);

        // TODO add swap to this test

        uint256 gasStart = gasleft();
        pair.removeLiquidity(TOKEN_0, _user, 5e17);
        uint256 gas = gasStart - gasleft();

        emit log_named_uint("gas for partial removal", gas);
        assertEq(gas, 8934);

        gasStart = gasleft();
        pair.removeLiquidity(TOKEN_0, _user, 1e18);
        gas = gasStart - gasleft();

        emit log_named_uint("gas for FULL removal", gas);
        assertEq(gas, 5215);
    }
}
