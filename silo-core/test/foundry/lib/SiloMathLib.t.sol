// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../../contracts/lib/SiloMathLib.sol";

// forge test -vv --mc SiloMathLibTest
contract SiloMathLibTest is Test {
    address public config = address(10001);
    address public asset = address(10002);
    address public model = address(10003);

    function setUp() public {}

    function test_liquidity(uint256 _collateralAssets, uint256 _debtAssets) public {
        if (_debtAssets >= _collateralAssets) {
            assertEq(SiloMathLib.liquidity(_collateralAssets, _debtAssets), 0);
        } else {
            assertEq(SiloMathLib.liquidity(_collateralAssets, _debtAssets), _collateralAssets - _debtAssets);
        }
    }

    function test_calculateUtilization(uint256 _collateralAssets, uint256 _debtAssets) public {
        uint256 dp = 1e18;

        vm.assume(_collateralAssets > 0);
        vm.assume(_debtAssets < type(uint128).max);
        uint256 u = _debtAssets * dp / _collateralAssets;
        vm.assume(u <= dp);

        assertEq(SiloMathLib.calculateUtilization(dp, _collateralAssets, _debtAssets), u);

        assertEq(SiloMathLib.calculateUtilization(dp, 1e18, 0.9e18), 0.9e18);
        assertEq(SiloMathLib.calculateUtilization(dp, 1e18, 0.1e18), 0.1e18);
        assertEq(SiloMathLib.calculateUtilization(dp, 10e18, 1e18), 0.1e18);
        assertEq(SiloMathLib.calculateUtilization(dp, 100e18, 25e18), 0.25e18);
        assertEq(SiloMathLib.calculateUtilization(dp, 100e18, 49e18), 0.49e18);
    }

    function test_calculateUtilizationWithMax(uint256 _dp, uint256 _collateralAssets, uint256 _debtAssets) public {
        vm.assume(_debtAssets < type(uint128).max);
        vm.assume(_dp < type(uint128).max);

        uint256 standardDp = 1e18;

        assertEq(SiloMathLib.calculateUtilization(standardDp, 0, _debtAssets), 0);
        assertEq(SiloMathLib.calculateUtilization(standardDp, _collateralAssets, 0), 0);
        assertEq(SiloMathLib.calculateUtilization(0, _collateralAssets, _debtAssets), 0);

        uint256 u = SiloMathLib.calculateUtilization(_dp, _collateralAssets, _debtAssets);
        assertTrue(u <= _dp);
    }
}
