// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {SiloMathLib} from "silo-core/contracts/lib/SiloMathLib.sol";

// forge test -vv --mc LiquidityTest
contract LiquidityTest is Test {
    /*
    forge test -vv --mt test_liquidity
    */
    function test_liquidity() public pure {
        assertEq(SiloMathLib.liquidity(0, 0), 0);
        assertEq(SiloMathLib.liquidity(100, 10), 90);
        assertEq(SiloMathLib.liquidity(1e18, 1), 999999999999999999);
        assertEq(SiloMathLib.liquidity(1e18, 0.1e18), 0.9e18);
        assertEq(SiloMathLib.liquidity(25000e18, 7999e18), 17001e18);
        assertEq(SiloMathLib.liquidity(25000e18, 30000e18), 0);
    }
}
