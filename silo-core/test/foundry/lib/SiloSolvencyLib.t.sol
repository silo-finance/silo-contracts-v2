// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../../contracts/lib/SiloSolvencyLib.sol";


// forge test -vv --mc SiloSolvencyLibTest
contract SiloSolvencyLibTest is Test {
    uint256 internal constant BASIS_POINTS = 1e4;

    address constant COLLATERAL_ASSET = address(0xc01a);
    address constant DEBT_ASSET = address(0xdeb);

    address constant COLLATERAL_ORACLE = address(0x555555);
    address constant DEBT_ORACLE = address(0x77777);

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

    /*
    forge test -vv --mt test_SiloSolvencyLib_getPositionValues_pass
    */
    function test_SiloSolvencyLib_getPositionValues_pass() public {
        uint256 collateralAssets = 20;
        uint256 protectedAssets = 10;
        uint256 debtAssets = 3;

        SiloSolvencyLib.LtvData memory ltvData = SiloSolvencyLib.LtvData(
            ISiloOracle(COLLATERAL_ORACLE),
            ISiloOracle(DEBT_ORACLE),
            collateralAssets,
            protectedAssets,
            debtAssets
        );

        _quoteMocks(ltvData, 9876, 1234);

        (
            uint256 collateralValue, uint256 debtValue
        ) = SiloSolvencyLib.getPositionValues(ltvData, COLLATERAL_ASSET, DEBT_ASSET);

        assertEq(collateralValue, 9876, "collateralValue");
        assertEq(debtValue, 1234, "debtValue");
    }

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

        assertEq(ltv, BASIS_POINTS + 1, "when only debt");
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
        vm.assume(sumOfCollateralAssets < type(uint256).max / BASIS_POINTS);

        SiloSolvencyLib.LtvData memory ltvData = SiloSolvencyLib.LtvData(
            noOracle, noOracle, _collateralAssets, _protectedAssets, _debtAssets
        );

        address any = address(1);

        (,, uint256 ltv) = SiloSolvencyLib.calculateLtv(ltvData, any, any);

        uint256 expectedLtv;

        if (sumOfCollateralAssets == 0 && _debtAssets == 0) {
            // expectedLtv is 0;
        } else if (sumOfCollateralAssets == 0) {
            expectedLtv = BASIS_POINTS + 1; // +1 to be over 100%
        } else {
            // TODO when 128 the whole below math can be unchecked, cast to 256!
            expectedLtv = _debtAssets * BASIS_POINTS / sumOfCollateralAssets;
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
        vm.assume(sumOfCollateralAssets < type(uint256).max / BASIS_POINTS);
        vm.assume(sumOfCollateralAssets != 0);

        SiloSolvencyLib.LtvData memory ltvData = SiloSolvencyLib.LtvData(
            ISiloOracle(COLLATERAL_ORACLE), ISiloOracle(DEBT_ORACLE), _protectedAssets, _collateralAssets, _debtAssets
        );

        _quoteMocks(ltvData, 9999, 1111);

        (,, uint256 ltv) = SiloSolvencyLib.calculateLtv(ltvData, COLLATERAL_ASSET, DEBT_ASSET);

        assertEq(ltv, 1111 * BASIS_POINTS / 9999, "constant values, constant ltv");
    }

    function _quoteMocks(SiloSolvencyLib.LtvData memory _ltvData, uint256 _quoteCollateral, uint256 _quoteDebt) private {
        vm.mockCall(
            COLLATERAL_ORACLE,
            abi.encodeWithSelector(ISiloOracle.quote.selector, _ltvData.borrowerCollateralAssets + _ltvData.borrowerProtectedAssets, COLLATERAL_ASSET),
            abi.encode(_quoteCollateral)
        );

        vm.mockCall(
            DEBT_ORACLE,
            abi.encodeWithSelector(ISiloOracle.quote.selector, _ltvData.borrowerDebtAssets, DEBT_ASSET),
            abi.encode(_quoteDebt)
        );
    }
}
