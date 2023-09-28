// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "silo-core/contracts/lib/SiloSolvencyLib.sol";

import "../../_common/MockOracleQuote.sol";

/*
forge test -vv --mc GetPositionValuesTest
*/
contract GetPositionValuesTest is Test, MockOracleQuote {
    uint256 internal constant BASIS_POINTS = 1e4;

    /*
    forge test -vv --mt test_SiloSolvencyLib_BASIS_POINTS
    */
    function test_SiloSolvencyLib_BASIS_POINTS() public {
        assertEq(BASIS_POINTS, SiloSolvencyLib._BASIS_POINTS, "BASIS_POINTS");
    }

    /*
    forge test -vv --mt test_SiloSolvencyLib_getPositionValues_noOracle
    */
    function test_SiloSolvencyLib_getPositionValues_noOracle() public {
        ISiloOracle noOracle;
        uint256 collateralAssets = 20;
        uint256 protectedAssets = 10;
        uint256 debtAssets = 3;

        SiloSolvencyLib.LtvData memory ltvData = SiloSolvencyLib.LtvData(
            noOracle, noOracle, protectedAssets, collateralAssets, debtAssets
        );

        address any = address(1);

        (uint256 collateralValue, uint256 debtValue) = SiloSolvencyLib.getPositionValues(ltvData, any, any);

        assertEq(collateralValue, collateralAssets + protectedAssets, "collateralValue");
        assertEq(debtValue, debtAssets, "debtValue");
    }
}
