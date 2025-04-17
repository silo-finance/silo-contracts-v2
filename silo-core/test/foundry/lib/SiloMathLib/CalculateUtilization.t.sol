// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {SiloMathLib} from "silo-core/contracts/lib/SiloMathLib.sol";

// forge test -vv --mc CalculateUtilizationTest
contract CalculateUtilizationTest is Test {
    /*
    forge test -vv --mt test_calculateUtilization_fuzz
    */
    function test_calculateUtilization_fuzz(uint256 _collateralAssets, uint256 _debtAssets) public pure {
        uint256 dp = 1e18;

        assertEq(SiloMathLib.calculateUtilization(dp, 1e18, 0.9e18), 0.9e18);
        assertEq(SiloMathLib.calculateUtilization(dp, 1e18, 0.1e18), 0.1e18);
        assertEq(SiloMathLib.calculateUtilization(dp, 10e18, 1e18), 0.1e18);
        assertEq(SiloMathLib.calculateUtilization(dp, 100e18, 25e18), 0.25e18);
        assertEq(SiloMathLib.calculateUtilization(dp, 100e18, 49e18), 0.49e18);
        assertEq(SiloMathLib.calculateUtilization(1e4, 100e18, 49e18), 0.49e4);

        assertEq(SiloMathLib.calculateUtilization(1e18, 0, _debtAssets), 0);
        assertEq(SiloMathLib.calculateUtilization(1e18, _collateralAssets, 0), 0);
        assertEq(SiloMathLib.calculateUtilization(0, _collateralAssets, _debtAssets), 0);
    }

    /*
    forge test -vv --mt test_calculateUtilizationWithMax_fuzz
    */
    function test_calculateUtilizationWithMax_fuzz(uint256 _dp, uint256 _collateralAssets, uint256 _debtAssets)
        public
        pure
    {
        vm.assume(_debtAssets < type(uint128).max);
        vm.assume(_dp < type(uint128).max);

        assertTrue(SiloMathLib.calculateUtilization(_dp, _collateralAssets, _debtAssets) <= _dp);
    }

    /*
    forge test -vv --mt test_utilizationEqualDP_fuzz
    */
    function test_utilizationEqualDP_fuzz(uint256 _dp, uint256 _collateralAssets, uint256 _debtAssets)
        public
        pure
    {
        vm.assume(_dp != 0 && _collateralAssets != 0 && _debtAssets != 0);
        vm.assume(type(uint256).max / _dp < _debtAssets / _collateralAssets);

        uint256 utilization = SiloMathLib.calculateUtilization(_dp, _collateralAssets, _debtAssets);

        assertEq(utilization, _dp);
    }
}
