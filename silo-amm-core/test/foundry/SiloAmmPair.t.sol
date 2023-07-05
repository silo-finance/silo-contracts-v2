// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "silo-amm-periphery/contracts/interfaces/IFeeManager.sol";

import "../../contracts/SiloAmmPair.sol";
import "../../contracts/interfaces/ISiloAmmPair.sol";
import "./helpers/Fixtures.sol";
import "./helpers/TestToken.sol";
import "../../../silo-amm-periphery/contracts/interfaces/IFeeManager.sol";

/*
    FOUNDRY_PROFILE=amm-core forge test -vv --match-contract SiloAmmPairTest
*/
contract SiloAmmPairTest is Test, Fixtures {
    uint256 constant ONE = 1e18;
    bool constant CLEAN_UP = false;
    address immutable TOKEN_0;
    address immutable TOKEN_1;
    address immutable SILO;

    SiloAmmPair immutable pair;

    constructor() {
        address router = address(1);
        ISiloOracle oracle0;
        ISiloOracle oracle1;
        IFeeManager.FeeSetup memory fee = IFeeManager.FeeSetup(address(1), 0);
        address bridge;

        SILO = address(this);

        address t1 = address(new TestToken("A"));
        address t2 = address(new TestToken("B"));

        (TOKEN_0, TOKEN_1) = t1 < t2 ? (t1, t2) : (t2, t1);

        pair = new SiloAmmPair(router, address(this), TOKEN_0, TOKEN_1, oracle0, oracle1, bridge, fee, ammPriceConfig);
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

        assertEq(gas, 7810);

        assertEq(reserve0, 0);
        assertEq(reserve1, 0);
        assertEq(blockTimestampLast, 0);
    }

    /*
        FOUNDRY_PROFILE=amm-core forge test -vv --match-test test_SiloAmmPair_getOraclePrice_init
    */
    function test_SiloAmmPair_getOraclePrice_init() public {
        uint256 gasStart = gasleft();
        uint256 debtPrice = pair.getQuoteFromOracle(1e18, TOKEN_0);
        uint256 gasEnd = gasleft();

        uint256 gas = gasStart - gasEnd;
        emit log_named_uint("gas", gas);

        assertEq(gas, 3548);
        assertEq(debtPrice, 1e18);
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

        assertEq(gas, 204491);
        assertEq(shares, amount, "initial amount == shares");

        gasStart = gasleft();
        uint256 shares2 = pair.addLiquidity(TOKEN_0, _user, true, amount, value);
        gas = gasStart - gasleft();

        emit log_named_uint("gas #2", gas);

        assertEq(gas, 170370, "gas usage for adding liquidity with cleanup");
        assertEq(shares, shares2, "expect same shares");
    }

    /*
        FOUNDRY_PROFILE=amm-core forge test -vv --match-test test_SiloAmmPair_removeLiquidity_gas
    */
    function test_SiloAmmPair_removeLiquidity_gas() public {
        address _user = address(333);
        uint256 amount = 1e18;
        uint256 value = amount; // price is 1:1 with debt

        // mint collateral
        TestToken(TOKEN_0).mint(SILO, amount);
        TestToken(TOKEN_0).approve(address(pair), type(uint256).max); // approve max saves gas
        pair.addLiquidity(TOKEN_0, _user, CLEAN_UP, amount, value);

        uint amount0Out = amount / 3;
        uint amount1Out = 0;
        uint debtIn = pair.getAmountIn(TOKEN_0, amount0Out, 0);
        address to = address(9999);

        // mint debt
        TestToken(TOKEN_1).mint(address(this), debtIn);
        TestToken(TOKEN_1).approve(address(pair), type(uint256).max);

        uint256 gasStart = gasleft();
        pair.swap(amount0Out, amount1Out, to, "");
        uint256 gas = gasStart - gasleft();

        emit log_named_uint("gas for swap", gas);
        assertEq(gas, 85442);
        assertEq(IERC20(TOKEN_0).balanceOf(address(this)), 666666666666666667, "expect collateral in `to` wallet");

        gasStart = gasleft();
        pair.exactInSwap(TOKEN_1, 1e17, to, "");
        gas = gasStart - gasleft();

        emit log_named_uint("gas for exactInSwap", gas);
        assertEq(gas, 19731);
        assertEq(IERC20(TOKEN_0).balanceOf(address(this)), 566666666666666667, "expect collateral in `to` wallet");

        gasStart = gasleft();
        pair.removeLiquidity(TOKEN_0, _user, 5e17);
        gas = gasStart - gasleft();

        emit log_named_uint("gas for partial removal", gas);
        assertEq(gas, 7098);

        gasStart = gasleft();
        pair.removeLiquidity(TOKEN_0, _user, 1e18);
        gas = gasStart - gasleft();

        emit log_named_uint("gas for FULL removal", gas);
        assertEq(gas, 5376);
    }
}
