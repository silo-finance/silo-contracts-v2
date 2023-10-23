// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "silo-core/contracts/lib/SiloSolvencyLib.sol";

import "../../_common/MockOracleQuote.sol";

/*
forge test -vv --mc CalculateLtvTest
*/
contract CalculateLtvTest is Test, MockOracleQuote {
    uint256 internal constant DECIMALS_POINTS = 1e18;

    /*
    forge test -vv --mt test_SiloSolvencyLib_calculateLtv_noOracle_zero
    */
    function test_SiloSolvencyLib_calculateLtv_noOracle_zero() public {
        uint128 zero;

        ISiloOracle noOracle;

        SiloSolvencyLib.LtvData memory ltvData = SiloSolvencyLib.LtvData(
            noOracle, noOracle, zero, zero, zero
        );

        address any = address(1);

        (,, uint256 ltv) = SiloSolvencyLib.calculateLtv(ltvData, any, any);

        assertEq(ltv, 0, "no debt no collateral");
    }

    /*
    forge test -vv --mt test_SiloSolvencyLib_calculateLtv_noOracle_infinity
    */
    function test_SiloSolvencyLib_calculateLtv_noOracle_infinity() public {
        uint128 zero;
        uint128 debtAssets = 1;

        ISiloOracle noOracle;

        SiloSolvencyLib.LtvData memory ltvData = SiloSolvencyLib.LtvData(
            noOracle, noOracle, zero, zero, debtAssets
        );

        address any = address(1);

        (,, uint256 ltv) = SiloSolvencyLib.calculateLtv(ltvData, any, any);

        assertEq(ltv, SiloSolvencyLib._INFINITY, "when only debt");
    }

    /*
    forge test -vv --mt test_SiloSolvencyLib_calculateLtv_noOracle_fuzz
    */
    function test_SiloSolvencyLib_calculateLtv_noOracle_fuzz(
        uint128 _collateralAssets,
        uint128 _protectedAssets,
        uint128 _debtAssets
    ) public {
        ISiloOracle noOracle;
        uint256 sumOfCollateralAssets = uint256(_collateralAssets) + _protectedAssets;
        // because this is the same token, we assume the sum can not be higher than uint128
        // TODO when turn on uint128 this test need to be changed
        // vm.assume(totalAssets < type(uint128).max);
        vm.assume(sumOfCollateralAssets < type(uint256).max / DECIMALS_POINTS);

        SiloSolvencyLib.LtvData memory ltvData = SiloSolvencyLib.LtvData(
            noOracle, noOracle, _collateralAssets, _protectedAssets, _debtAssets
        );

        address any = address(1);

        (,, uint256 ltv) = SiloSolvencyLib.calculateLtv(ltvData, any, any);

        uint256 expectedLtv;

        if (sumOfCollateralAssets == 0 && _debtAssets == 0) {
            // expectedLtv is 0;
        } else if (sumOfCollateralAssets == 0) {
            expectedLtv = SiloSolvencyLib._INFINITY;
        } else {
            // TODO when 128 the whole below math can be unchecked, cast to 256!
            expectedLtv = _debtAssets * DECIMALS_POINTS / sumOfCollateralAssets;
        }

        assertEq(ltv, expectedLtv, "ltv");
    }

    /*
    forge test -vv --mt test_SiloSolvencyLib_calculateLtv_constant
    */
    function test_SiloSolvencyLib_calculateLtv_constant(
        uint128 _collateralAssets,
        uint128 _protectedAssets,
        uint128 _debtAssets
    ) public {
        vm.assume(_debtAssets != 0);
        uint256 sumOfCollateralAssets = uint256(_collateralAssets) + _protectedAssets;
        // because this is the same token, we assume the sum can not be higher than uint128
        // TODO when turn on uint128 this test need to be changed
        // vm.assume(totalAssets < type(uint128).max);
        vm.assume(sumOfCollateralAssets < type(uint256).max / DECIMALS_POINTS);
        vm.assume(sumOfCollateralAssets != 0);

        SiloSolvencyLib.LtvData memory ltvData = SiloSolvencyLib.LtvData(
            ISiloOracle(COLLATERAL_ORACLE), ISiloOracle(DEBT_ORACLE), _protectedAssets, _collateralAssets, _debtAssets
        );

        _oraclesQuoteMocks(ltvData, 9999, 1111);

        (,, uint256 ltv) = SiloSolvencyLib.calculateLtv(ltvData, COLLATERAL_ASSET, DEBT_ASSET);

        assertEq(ltv, 1111 * DECIMALS_POINTS / 9999, "constant values, constant ltv");
    }
}
