// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "silo-core/contracts/lib/SiloSolvencyLib.sol";

import {OraclesHelper} from "../../_common/OraclesHelper.sol";

/*
forge test -vv --mc GetPositionValuesTest
*/
contract GetPositionValuesTest is Test, OraclesHelper {
    uint256 internal constant _PRECISION_DECIMALS = 1e18;

    /*
    forge test -vv --mt test_SiloSolvencyLib_PRECISION_DECIMALS
    */
    function test_SiloSolvencyLib_PRECISION_DECIMALS() public {
        assertEq(_PRECISION_DECIMALS, SiloSolvencyLib._PRECISION_DECIMALS, "_PRECISION_DECIMALS");
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
