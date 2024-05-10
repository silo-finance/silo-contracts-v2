// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {IInterestRateModelV2} from "silo-core/contracts/interfaces/IInterestRateModelV2.sol";
import {InterestRateModelV2} from "silo-core/contracts/interestRateModel/InterestRateModelV2.sol";
import {InterestRateModelV2ConfigFactory} from "silo-core/contracts/interestRateModel/InterestRateModelV2ConfigFactory.sol";

import {InterestRateModelConfigs} from "../_common/InterestRateModelConfigs.sol";
import {InterestRateModelV2Impl} from "./InterestRateModelV2Impl.sol";
import {InterestRateModelV2Checked} from "./InterestRateModelV2Checked.sol";

// forge test -vv --mc InterestRateModelV2Test
contract InterestRateModelV2Test is Test, InterestRateModelConfigs {
    uint256 constant TODAY = 1682885514;
    InterestRateModelV2 immutable INTEREST_RATE_MODEL;

    uint256 constant DP = 10 ** 18;

    constructor() {
        INTEREST_RATE_MODEL = new InterestRateModelV2();
    }

    function test_IRM_decimals() public {
        uint256 dp = INTEREST_RATE_MODEL.DP();
        uint256 decimals = INTEREST_RATE_MODEL.decimals();

        assertEq(dp, 10 ** decimals);
    }

    function test_IRM_RCOMP_MAX() public {
        assertEq(INTEREST_RATE_MODEL.RCOMP_MAX(), 2 ** 16 * DP);
    }

    function test_IRM_X_MAX() public {
        assertEq(INTEREST_RATE_MODEL.X_MAX(), 11090370147631773313);
    }

    // forge test -vvv --mt test_IRM_ASSET_DATA_OVERFLOW_LIMIT
    function test_IRM_ASSET_DATA_OVERFLOW_LIMIT() public {
        assertEq(INTEREST_RATE_MODEL.ASSET_DATA_OVERFLOW_LIMIT(), uint256(type(uint256).max / (2 ** 16 * DP)));
    }

    function test_IRM_calculateCompoundInterestRate_InvalidTimestamps() public {
        IInterestRateModelV2.ConfigWithState memory c;
        vm.expectRevert(IInterestRateModelV2.InvalidTimestamps.selector);
        INTEREST_RATE_MODEL.calculateCompoundInterestRate(c, 0, 0, 1, 0);
    }

    function test_IRM_calculateCurrentInterestRate_InvalidTimestamps() public {
        IInterestRateModelV2.ConfigWithState memory c;
        vm.expectRevert(IInterestRateModelV2.InvalidTimestamps.selector);
        INTEREST_RATE_MODEL.calculateCurrentInterestRate(c, 0, 0, 1, 0);
    }
    
    // forge test -vv --mt test_IRM_calculateCurrentInterestRate_CAP
    function test_IRM_calculateCurrentInterestRate_CAP() public {
        uint256 rcur = INTEREST_RATE_MODEL.calculateCurrentInterestRate(
            _configWithState(),
            100e18, // _totalDeposits,
            99e18, // _totalBorrowAmount,
            TODAY, // _interestRateTimestamp,
            TODAY + 60 days // after 59 days we got capped
        );

        assertEq(rcur, 10**20, "expect to return CAP");
    }

    function test_IRM_calculateCurrentInterestRate_revertsWhenTimestampInvalid() public {
        IInterestRateModelV2.ConfigWithState memory emptyConfig;

        // currentTime should always be larger than last, so this should revert
        uint256 lastTransactionTime = 1;
        uint256 currentTime = 0;

        vm.expectRevert(IInterestRateModelV2.InvalidTimestamps.selector);
        INTEREST_RATE_MODEL.calculateCurrentInterestRate(emptyConfig, 0, 0, lastTransactionTime, currentTime);
    }

    // forge test -vv --mt test_IRM_calculateCompoundInterestRateWithOverflowDetection_CAP_fuzz
    function test_IRM_calculateCompoundInterestRateWithOverflowDetection_CAP_fuzz(uint256 _t) public {
        vm.assume(_t < 5 * 365 days);

        uint256 cap = 3170979198376 * (1 + _t);

        (uint256 rcur,,,) = INTEREST_RATE_MODEL.calculateCompoundInterestRateWithOverflowDetection(
            _configWithState(),
            100e18, // _totalDeposits,
            99e18, // _totalBorrowAmount,
            TODAY, // _interestRateTimestamp,
            TODAY + 1 + _t // +1 so we always have some time pass
        );

        assertGt(rcur, 0, "expect to get some %");
        assertLe(rcur, cap, "expect to have CAP");
    }

    // forge test -vv --mt test_IRM_calculateCompoundInterestRateWithOverflowDetection_ZERO
    function test_IRM_calculateCompoundInterestRateWithOverflowDetection_ZERO() public {
        (uint256 rcur,,,) = INTEREST_RATE_MODEL.calculateCompoundInterestRateWithOverflowDetection(
            _configWithState(),
            100e18, // _totalDeposits,
            99e18, // _totalBorrowAmount,
            TODAY, // _interestRateTimestamp,
            TODAY
        );

        assertEq(rcur, 0, "expect to get 0 for time 0");
    }

    // forge test -vv --mt test_IRM_calculateRComp
    /// forge-config: core-test.fuzz.runs = 10000
    function test_IRM_calculateRComp(uint256 _totalDeposits, uint256 _totalBorrowAmount, int256 _x) public {
        InterestRateModelV2Impl impl = new InterestRateModelV2Impl();
        InterestRateModelV2Checked implChecked = new InterestRateModelV2Checked();

        (uint256 rcomp1, bool overflow1) = impl.calculateRComp(_totalDeposits, _totalBorrowAmount, _x);
        emit log_named_uint("rcomp1", rcomp1);

        (uint256 rcomp2, bool overflow2) = implChecked._calculateRComp(_totalDeposits, _totalBorrowAmount, _x);
        emit log_named_uint("rcomp2", rcomp2);

        emit log_named_string(
            "overflow",
            overflow1 == overflow2 ? "same" : string.concat("different: 1st is ", overflow1 ? "true" : "false")
        );

        assertEq(rcomp1, rcomp2, "expect exact rcomp value");
        assertEq(overflow1, overflow2, "expect exact overflow value");
    }
}
