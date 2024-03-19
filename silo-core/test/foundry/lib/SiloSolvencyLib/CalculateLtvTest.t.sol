// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {MathUpgradeable} from "openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol";
import {SolvencyLib} from "silo-core/contracts/liquidation/lib/SolvencyLib.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

import {OraclesHelper} from "../../_common/OraclesHelper.sol";

/*
forge test -vv --mc CalculateLtvTest
*/
contract CalculateLtvTest is Test, OraclesHelper {
    uint256 internal constant DECIMALS_POINTS = 1e18;

    /*
    forge test -vv --mt test_SiloStdLib_calculateLtv_noOracle_zero
    */
    function test_SiloStdLib_calculateLtv_noOracle_zero() public {
        uint128 zero;

        ISiloOracle noOracle;

        ISilo.LtvData memory ltvData = ISilo.LtvData(
            noOracle, noOracle, zero, zero, zero
        );

        address any = address(1);

        (,, uint256 ltv) = SolvencyLib.calculateLtv(ltvData, any, any);

        assertEq(ltv, 0, "no debt no collateral");
    }

    /*
    forge test -vv --mt test_SiloStdLib_calculateLtv_noOracle_infinity
    */
    function test_SiloStdLib_calculateLtv_noOracle_infinity() public {
        uint128 zero;
        uint128 debtAssets = 1;

        ISiloOracle noOracle;

        ISilo.LtvData memory ltvData = ISilo.LtvData(
            noOracle, noOracle, zero, zero, debtAssets
        );

        address any = address(1);

        (,, uint256 ltv) = SolvencyLib.calculateLtv(ltvData, any, any);

        assertEq(ltv, SolvencyLib._INFINITY, "when only debt");
    }

    /*
    forge test -vv --mt test_SiloStdLib_calculateLtv_noOracle_fuzz
    */
    function test_SiloStdLib_calculateLtv_noOracle_fuzz(
        uint128 _collateralAssets,
        uint128 _protectedAssets,
        uint128 _debtAssets
    ) public {
        ISiloOracle noOracle;
        uint256 sumOfCollateralAssets = uint256(_collateralAssets) + _protectedAssets;
        // because this is the same token, we assume the sum can not be higher than uint128
        vm.assume(sumOfCollateralAssets < type(uint256).max / DECIMALS_POINTS);

        ISilo.LtvData memory ltvData = ISilo.LtvData(
            noOracle, noOracle, _collateralAssets, _protectedAssets, _debtAssets
        );

        address any = address(1);

        (,, uint256 ltv) = SolvencyLib.calculateLtv(ltvData, any, any);

        uint256 expectedLtv;

        if (sumOfCollateralAssets == 0 && _debtAssets == 0) {
            // expectedLtv is 0;
        } else if (sumOfCollateralAssets == 0) {
            expectedLtv = SolvencyLib._INFINITY;
        } else {
            expectedLtv = MathUpgradeable.mulDiv(_debtAssets, DECIMALS_POINTS, sumOfCollateralAssets, MathUpgradeable.Rounding.Up);
        }

        assertEq(ltv, expectedLtv, "ltv");
    }

    /*
    forge test -vv --mt test_SiloStdLib_calculateLtv_constant
    */
    function test_SiloStdLib_calculateLtv_constant(
        uint128 _collateralAssets,
        uint128 _protectedAssets,
        uint128 _debtAssets
    ) public {
        vm.assume(_debtAssets != 0);
        uint256 sumOfCollateralAssets = uint256(_collateralAssets) + _protectedAssets;
        // because this is the same token, we assume the sum can not be higher than uint256
        vm.assume(sumOfCollateralAssets < type(uint256).max / DECIMALS_POINTS);
        vm.assume(sumOfCollateralAssets != 0);

        ISilo.LtvData memory ltvData = ISilo.LtvData(
            ISiloOracle(COLLATERAL_ORACLE), ISiloOracle(DEBT_ORACLE), _protectedAssets, _collateralAssets, _debtAssets
        );

        uint256 collateralSum = ltvData.borrowerCollateralAssets + ltvData.borrowerProtectedAssets;
        collateralOracle.quoteMock(collateralSum, COLLATERAL_ASSET, 9999);
        debtOracle.quoteMock(ltvData.borrowerDebtAssets, DEBT_ASSET, 1111);

        (,, uint256 ltv) = SolvencyLib.calculateLtv(ltvData, COLLATERAL_ASSET, DEBT_ASSET);

        assertEq(
            ltv,
            MathUpgradeable.mulDiv(1111, DECIMALS_POINTS, 9999, MathUpgradeable.Rounding.Up),
            "constant values, constant ltv"
        );
    }
}
