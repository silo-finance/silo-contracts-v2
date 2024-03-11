// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {SiloSolvencyLib} from "silo-core/contracts/lib/SiloSolvencyLib.sol";
import {PartialLiquidationExecLib} from "silo-core/contracts/liquidation/lib/PartialLiquidationExecLib.sol";
import {PartialLiquidationLib} from "silo-core/contracts/liquidation/lib/PartialLiquidationLib.sol";

import {OraclesHelper} from "../../../_common/OraclesHelper.sol";
import {OracleMock} from "../../../_mocks/OracleMock.sol";
import {PartialLiquidationExecLibImpl} from "../../../_common/PartialLiquidationExecLibImpl.sol";
import "./MaxRepayRawMath.sol";

// forge test -vv --mc MaxLiquidationTest
contract MaxLiquidationTest is Test, MaxRepayRawMath {
    /// @dev _LT_LIQUIDATION_MARGIN must match value from PartialLiquidationLib
    uint256 internal constant _LT_LIQUIDATION_MARGIN = 0.9e18; // 90%
    uint256 internal constant _DECIMALS_POINTS = 1e18; // 90%

    /*
    forge test -vv --mt test_maxLiquidation_fuzz
    */
    /// forge-config: core.fuzz.runs = 5000
    function test_maxLiquidation_fuzz(
        uint128 _sumOfCollateralAssets,
        uint128 _sumOfCollateralValue,
        uint128 _borrowerDebtAssets,
        uint64 _liquidityFee
    ) public {
        vm.assume(_liquidityFee < 0.40e18); // some reasonable fee
        vm.assume(_sumOfCollateralAssets > 0);
        // for tiny assets we doing full liquidation because it is to small to get down to expected minimal LTV
        vm.assume(_sumOfCollateralValue > 1);
        vm.assume(_borrowerDebtAssets > 1);

        // prevent overflow revert in test
        vm.assume(uint256(_borrowerDebtAssets) * _liquidityFee < type(uint128).max);

        uint256 lt = 0.85e18;
        uint256 borrowerDebtValue = _borrowerDebtAssets; // assuming quote is debt token, so value is 1:1
        uint256 ltvBefore = borrowerDebtValue * 1e18 / _sumOfCollateralValue;

        // if ltv will be less, then this math should not be executed in contract
        vm.assume(ltvBefore >= lt);

        (
            uint256 collateralToLiquidate, uint256 debtToRepay
        ) = PartialLiquidationLib.maxLiquidation(
            _sumOfCollateralAssets,
            _sumOfCollateralValue,
            _borrowerDebtAssets,
            borrowerDebtValue,
            lt,
            _liquidityFee
        );

        emit log_named_decimal_uint("collateralToLiquidate", collateralToLiquidate, 18);
        emit log_named_decimal_uint("debtToRepay", debtToRepay, 18);

        uint256 minExpectedLtv = PartialLiquidationLib.minAcceptableLTV(lt);
        emit log_named_decimal_uint("minExpectedLtv", minExpectedLtv, 16);
        emit log_named_decimal_uint("ltvBefore", ltvBefore, 16);

        uint256 raw = _estimateMaxRepayValueRaw(borrowerDebtValue, _sumOfCollateralValue, minExpectedLtv, _liquidityFee);
        emit log_named_decimal_uint("raw", raw, 18);

        uint256 deviation = raw > debtToRepay
            ? raw * _DECIMALS_POINTS / debtToRepay
            : debtToRepay * _DECIMALS_POINTS / raw;

        emit log_named_decimal_uint("deviation on raw calculation", deviation, 18);

        if (debtToRepay == _borrowerDebtAssets) {
            assertLe(deviation, 1.112e18, "[full] raw calculations - I'm accepting some % deviation (and dust)");
        } else {
            if (debtToRepay > 100) {
                assertLe(deviation, 1.065e18, "[partial] raw calculations - I'm accepting some % deviation");
            } else {
                assertLe(deviation, 2.0e18, "[partial] raw calculations - on tiny values we can have big deviation");
            }
        }

        uint256 ltvAfter = _ltv(
            _sumOfCollateralAssets,
            _sumOfCollateralValue,
            _borrowerDebtAssets,
            collateralToLiquidate,
            debtToRepay
        );

        emit log_named_decimal_uint("ltvAfter", ltvAfter, 16);

        if (debtToRepay == _borrowerDebtAssets) {
            emit log("full liquidation");
            // there is not really a way to verify this part other than check RAW result, what was done above
        } else {
            emit log("partial liquidation");

            assertLt(
                ltvAfter,
                lt,
                "we can not expect to be wei precise. as long as we below LT, it is OK"
            );
        }
    }

    function _ltv(
        uint256 _sumOfCollateralAssets,
        uint256 _sumOfCollateralValue,
        uint256 _borrowerDebtAssets,
        uint256 _collateralToLiquidate,
        uint256 _debtToRepay
    ) internal pure returns (uint256 ltv) {
        uint256 collateralLeft = _sumOfCollateralAssets - _collateralToLiquidate;
        uint256 collateralValueAfter = uint256(_sumOfCollateralValue) * collateralLeft / _sumOfCollateralAssets;
        if (collateralValueAfter == 0) return 0;

        uint256 debtLeft = _borrowerDebtAssets - _debtToRepay;
        ltv = debtLeft * 1e18 / collateralValueAfter;
    }
}
