// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISiloLiquidation} from "silo-core/contracts/interfaces/ISiloLiquidation.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {SiloSolvencyLib} from "silo-core/contracts/lib/SiloSolvencyLib.sol";
import {SiloLiquidationExecLib} from "silo-core/contracts/lib/SiloLiquidationExecLib.sol";
import {SiloLiquidationLib} from "silo-core/contracts/lib/SiloLiquidationLib.sol";

import {OraclesHelper} from "../../_common/OraclesHelper.sol";
import {OracleMock} from "../../_mocks/OracleMock.sol";
import {SiloLiquidationExecLibImpl} from "../../_common/SiloLiquidationExecLibImpl.sol";


// forge test -vv --mc MaxLiquidationTest
contract MaxLiquidationTest is Test, OraclesHelper {
    // this must match value from SiloLiquidationLib
    uint256 internal constant _LT_LIQUIDATION_MARGIN = 0.9e18; // 90%
    uint256 internal constant _DECIMALS_POINTS = 1e18; // 90%

    /*
    forge test -vv --mt test_maxLiquidation_fuzz
    */
    /// forge-config: core.fuzz.runs = 10000
    function test_maxLiquidation_fuzz(
//        uint128 _sumOfCollateralAssets,
//        uint128 _sumOfCollateralValue,
//        uint128 _borrowerDebtAssets,
//        uint64 _liquidityFee
    ) public {
        (
            uint128 _sumOfCollateralAssets, uint128 _sumOfCollateralValue, uint128 _borrowerDebtAssets, uint64 _liquidityFee
        ) = (5630, 5394, 5311, 3774);

        vm.assume(_liquidityFee < 0.40e18); // some reasonable fee
        vm.assume(_sumOfCollateralAssets > 0);
        // for tiny assets we doing full liquidation because it is to small to get down to expected minimal LTV
        vm.assume(_sumOfCollateralValue > 1);
        vm.assume(_borrowerDebtAssets > 1);

        uint256 lt = 0.85e18;
        uint256 borrowerDebtValue = _borrowerDebtAssets; // assuming quote is debt token, so value is 1:1
        uint256 ltvBefore = borrowerDebtValue * 1e18 / _sumOfCollateralValue;

        // if ltv will be less, then this math should not be executed in contract
        vm.assume(ltvBefore >= lt);

        (
            uint256 collateralToLiquidate, uint256 debtToRepay
        ) = SiloLiquidationLib.maxLiquidation(
            _sumOfCollateralAssets,
            _sumOfCollateralValue,
            _borrowerDebtAssets,
            borrowerDebtValue,
            lt,
            _liquidityFee
        );

        emit log_named_decimal_uint("collateralToLiquidate", collateralToLiquidate, 18);
        emit log_named_decimal_uint("debtToRepay", debtToRepay, 18);

        uint256 minExpectedLtv = SiloLiquidationLib.minAcceptableLTV(lt);
        emit log_named_decimal_uint("minExpectedLtv", minExpectedLtv, 16);
        emit log_named_decimal_uint("ltvBefore", ltvBefore, 16);

        uint256 raw = _estimateMaxRepayValueRaw(borrowerDebtValue, _sumOfCollateralValue, minExpectedLtv, _liquidityFee);
        emit log_named_decimal_uint("raw", raw, 18);

        assertEq(raw, debtToRepay, "raw calculations");

        uint256 ltvAfter = _ltv(
            _sumOfCollateralAssets,
            _sumOfCollateralValue,
            _borrowerDebtAssets,
            collateralToLiquidate,
            debtToRepay
        );

        emit log_named_decimal_uint("ltvAfter", ltvAfter, 16);


        uint256 precision = 0.01e18; // 1%

        assertLe(
            ltvAfter < precision ? ltvAfter : ltvAfter - precision,
            minExpectedLtv,
            "we need to be as close as possible to minExpectedLtv"
        );

        if (debtToRepay == _borrowerDebtAssets) {
            emit log("full liquidation");

            // on full liquidation, the only way to check, if result is correct is: when we repay less,
            // we will be still insolvent?
            uint256 ltvAfterBis = _ltv(
                _sumOfCollateralAssets,
                _sumOfCollateralValue,
                _borrowerDebtAssets,
                collateralToLiquidate,
                debtToRepay - 62
            );

            emit log_named_decimal_uint("ltvAfterBis", ltvAfterBis, 16);

            // we can have two edge cases here, either 1wei change nothing and LTV still 0
            // or it change a lot and we above LT
            if (ltvAfterBis > 0) assertGe(ltvAfterBis, minExpectedLtv, "if we repay less we still insolvent");
            else assertEq(ltvAfterBis, 0, "1 wei change nothing");
        } else {
            emit log("partial liquidation");

            uint256 ltvAfterBis = _ltv(
                _sumOfCollateralAssets,
                _sumOfCollateralValue,
                _borrowerDebtAssets,
                collateralToLiquidate,
                debtToRepay + 1
            );

            emit log_named_decimal_uint("ltvAfterBis", ltvAfterBis, 16);

            // in case of partial liquidation, when we do +1, we need to be above?

            assertGt(ltvAfter + precision, minExpectedLtv, "ltvAfter should be as close as possible to expected LTV");
        }
    }

    function _ltv(
        uint256 _sumOfCollateralAssets,
        uint256 _sumOfCollateralValue,
        uint256 _borrowerDebtAssets,
        uint256 _collateralToLiquidate,
        uint256 _debtToRepay
    ) internal returns (uint256 ltv) {
        uint256 collateralLeft = _sumOfCollateralAssets - _collateralToLiquidate;
        uint256 collateralValueAfter = uint256(_sumOfCollateralValue) * collateralLeft / _sumOfCollateralAssets;
        if (collateralValueAfter == 0) return 0;

        uint256 debtLeft = _borrowerDebtAssets - _debtToRepay;
        ltv = debtLeft * 1e18 / collateralValueAfter;
    }

    /// @dev the math is based on: (Dv - x)/(Cv - (x + xf)) = LT
    /// where Dv: debt value, Cv: collateral value, LT: expected LT, f: liquidation fee, x: is value we looking for
    /// x = (Dv - LT * Cv) / (DP - LT - LT * f)
    function _estimateMaxRepayValueRaw(
        uint256 _totalBorrowerDebtValue,
        uint256 _totalBorrowerCollateralValue,
        uint256 _ltvAfterLiquidation,
        uint256 _liquidityFee
    )
        private pure returns (uint256 repayValue)
    {
        repayValue = (
            _totalBorrowerDebtValue - _ltvAfterLiquidation * _totalBorrowerCollateralValue / _DECIMALS_POINTS
        ) * _DECIMALS_POINTS / (
            _DECIMALS_POINTS - _ltvAfterLiquidation - _ltvAfterLiquidation * _liquidityFee / _DECIMALS_POINTS
        );

        return repayValue > _totalBorrowerDebtValue ? _totalBorrowerDebtValue : repayValue;
    }
}
