// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";


import {PartialLiquidationLib} from "silo-core/contracts/hooks/liquidation/lib/PartialLiquidationLib.sol";

import {EstimateMaxRepayValueTestData} from "../../../../../data-readers/EstimateMaxRepayValueTestData.sol";

import {PartialLiquidationLibTest} from "./PartialLiquidationLib.t.sol";
 
/*
FOUNDRY_PROFILE=core_test forge test -vv --mc PartialLiquidationLibMaturityTest

incluse all raw tests from PartialLiquidationLib.t.sol but here we have maturityDate() endpoint
*/
contract PartialLiquidationLibMaturityTest is PartialLiquidationLibTest {
    uint256 public maturityDate = 1;

    function setUp() public virtual {
        vm.warp(1728192000);
        maturityDate = block.timestamp + 1;
    }

    modifier beforeMaturity() {
        maturityDate = block.timestamp + 1;
        _;
    }

    modifier afterMaturity() {
        maturityDate = block.timestamp - 1;
        _;
    }

    /*
        FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_PartialLiquidationLib_estimateMaxRepayValue_afterMaturity
    */
    function test_PartialLiquidationLib_estimateMaxRepayValue_afterMaturity() public afterMaturity {

        EstimateMaxRepayValueTestData json = new EstimateMaxRepayValueTestData();
        EstimateMaxRepayValueTestData.EMRVData[] memory data = json.readDataFromJson();

        assertGe(data.length, 1, "expect to have tests");

        for (uint256 i; i < data.length; i++) {
            uint256 repayValue = PartialLiquidationLib.estimateMaxRepayValue(
                data[i].input.totalBorrowerDebtValue,
                data[i].input.totalBorrowerCollateralValue,
                data[i].input.ltvAfterLiquidation,
                data[i].input.liquidationFee
            );

            if (data[i].input.totalBorrowerDebtValue != 0) {
                console.log("repayValue %s %s%", repayValue, repayValue / data[i].input.totalBorrowerDebtValue * 100);
            } else {
                console.log("repayValue %s", repayValue);
            }

            assertEq(repayValue, data[i].input.totalBorrowerDebtValue, _concatMsg(i, "expect 100% epayValue"));
        }
    }

    /*
        FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_PartialLiquidationLib_estimateMaxRepayValue_pass_beforeMaturity
    */
    function test_PartialLiquidationLib_estimateMaxRepayValue_pass_beforeMaturity() public beforeMaturity {
        test_PartialLiquidationLib_estimateMaxRepayValue_pass();
    }

    /*
        FOUNDRY_PROFILE=core_test forge test -vv --mt test_PartialLiquidationLib_estimateMaxRepayValue_raw_afterMaturity
    */
    function test_PartialLiquidationLib_estimateMaxRepayValue_raw_afterMaturity() public afterMaturity {
        // debtValue, CollateralValue, ltv, fee
        assertEq(
            PartialLiquidationLib.estimateMaxRepayValue(1e18, 1e18, 0.0080e18, 0.0010e18),
            1e18,
            "expect raw == estimateMaxRepayValue (1)"
        );

        // simulation values
        assertEq(
            PartialLiquidationLib.estimateMaxRepayValue(85e18, 1e18, 0.79e18, 0.03e18),
            85e18,
            "expect raw == estimateMaxRepayValue (2)"
        );

        // simulation values
        assertEq(
            PartialLiquidationLib.estimateMaxRepayValue(85e18, 111e18, 0.5e18, 0.1e18),
            85e18,
            "expect raw == estimateMaxRepayValue (3)"
        );
    }

    /*
        FOUNDRY_PROFILE=core_test forge test -vv --mt test_PartialLiquidationLib_estimateMaxRepayValue_raw_afterMaturity
    */
    function test_PartialLiquidationLib_estimateMaxRepayValue_raw_beforeMaturity() public beforeMaturity {
        test_PartialLiquidationLib_estimateMaxRepayValue_raw();
    }

       /*
        FOUNDRY_PROFILE=core_test forge test -vv --mt test_PartialLiquidationLib_estimateMaxRepayValue_fuzz_afterMaturity
    */
    function test_PartialLiquidationLib_estimateMaxRepayValue_fuzz_afterMaturity(
        uint256 _totalBorrowerDebtValue,
        uint256 _totalBorrowerCollateralValue,
        uint256 _ltvAfterLiquidation,
        uint256 _liquidationFee
    ) public afterMaturity {
        vm.assume(_totalBorrowerDebtValue != 0);
        vm.assume(_liquidationFee < 1e18);

        assertEq(
            PartialLiquidationLib.estimateMaxRepayValue(_totalBorrowerDebtValue, _totalBorrowerCollateralValue, _ltvAfterLiquidation, _liquidationFee),
            _totalBorrowerDebtValue,
            "afer maturity date always return 100% of debt"
        );
    }
}
