// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Strings} from "openzeppelin-contracts/utils/Strings.sol";

import "silo-core/contracts/interestRateModel/InterestRateModelV2.sol";
import "silo-core/contracts/interestRateModel/InterestRateModelV2ConfigFactory.sol";

import "./InterestRateModelV2Impl.sol";
import "../_common/InterestRateModelConfigs.sol";
import "../data-readers/RcompTestData.sol";


// forge test -vv --ffi --mc InterestRateModelV2RcompTest
contract InterestRateModelV2RcompTest is RcompTestData, InterestRateModelConfigs {
    InterestRateModelV2ConfigFactory immutable CONFIG_FACTORY;
    InterestRateModelV2Impl immutable INTEREST_RATE_MODEL;

    uint256 constant DP = 10 ** 18;
    uint256 constant BASIS_POINTS = 10000;

    constructor() {
        INTEREST_RATE_MODEL = new InterestRateModelV2Impl();
        CONFIG_FACTORY = new InterestRateModelV2ConfigFactory();
    }

    // forge test -vv --ffi --mt test_IRM_RcompData_Mock
    function test_IRM_RcompData_Mock() public {
        RcompData[] memory data = _readDataFromJson();

        uint256 totalDepositsOverflows;
        uint256 totalBorrowAmountOverflows;

        for (uint i; i < data.length; i++) {
            RcompData memory testCase = data[i];

            IInterestRateModelV2.ConfigWithState memory cfg = _toConfigWithState(testCase);

            (
                uint256 rcomp,
                int256 ri,
                int256 Tcrit,
                bool overflow
            ) = INTEREST_RATE_MODEL.calculateCompoundInterestRateWithOverflowDetection(
                cfg,
                testCase.input.totalDeposits,
                testCase.input.totalBorrowAmount,
                testCase.input.lastTransactionTime,
                testCase.input.currentTime
            );

            assertEq(overflow, testCase.expected.didOverflow == 1, _concatMsg(i, "didOverflow"));

            if (testCase.expected.compoundInterest == 0) {
                assertEq(rcomp, testCase.expected.compoundInterest, _concatMsg(i, "compoundInterest"));
            } else {
                uint256 diff = _diff(rcomp, testCase.expected.compoundInterest);

                // allow maximum of 0.25% (25bps) deviation between high precision test results and smart contracts output
                assertLe(diff, 25, _concatMsg(i, "[rcomp] allow maximum of 0.25% (25bps) "));
            }

            if (testCase.expected.newIntegratorState == 0) {
                assertEq(ri, testCase.expected.newIntegratorState, _concatMsg(i, "newIntegratorState"));
            } else {
                uint256 diff = _diff(ri, testCase.expected.newIntegratorState);

                // allow maximum of 0.25% (25bps) deviation between high precision test results and smart contracts output
                assertLe(diff, 25, _concatMsg(i, "[ri] allow maximum of 0.25% (25bps) "));
            }

            if (testCase.expected.newTcrit == 0) {
                assertEq(Tcrit, testCase.expected.newTcrit, _concatMsg(i, "newTcrit"));
            } else {
                uint256 diff = _diff(Tcrit, testCase.expected.newTcrit);

                // allow maximum of 0.25% (25bps) deviation between high precision test results and smart contracts output
                assertLe(diff, 25, _concatMsg(i, "[newTcrit] allow maximum of 0.25% (25bps) "));
            }

            ISilo.UtilizationData memory utilizationData = ISilo.UtilizationData(
                testCase.input.totalDeposits,
                testCase.input.totalBorrowAmount,
                uint64(testCase.input.lastTransactionTime)
            );

            if (testCase.input.totalDeposits != utilizationData.collateralAssets) {
                totalDepositsOverflows++;
                continue;
            }
            if (testCase.input.totalBorrowAmount != utilizationData.debtAssets) {
                totalBorrowAmountOverflows++;
                continue;
            }

            address silo = address(uint160(i));

            (, IInterestRateModelV2Config configAddress) = CONFIG_FACTORY.create(_toConfigStruct(testCase));

            vm.prank(silo);
            INTEREST_RATE_MODEL.connect(address(configAddress));

            INTEREST_RATE_MODEL.mockSetup(silo, testCase.input.integratorState, testCase.input.Tcrit);
            vm.mockCall(silo, abi.encodeWithSelector(ISilo.utilizationData.selector), abi.encode(utilizationData));
            uint256 compoundInterestRate = INTEREST_RATE_MODEL.getCompoundInterestRate(silo, testCase.input.currentTime);
            assertEq(compoundInterestRate, rcomp, _concatMsg(i, "getCompoundInterestRate()"));
        }

        emit log_named_uint("totalBorrowAmountOverflows", totalBorrowAmountOverflows);
        emit log_named_uint("totalDepositsOverflows", totalDepositsOverflows);
        emit log_named_uint("total cases", data.length);
    }

    // forge test -vv --ffi --mt test_IRM_RcompData_Update
    function test_IRM_RcompData_Update() public {
        RcompData[] memory data = _readDataFromJson();

        for (uint i; i < data.length; i++) {
            RcompData memory testCase = data[i];

            IInterestRateModelV2.ConfigWithState memory cfg = _toConfigWithState(testCase);

            (
                , int256 ri,
                int256 Tcrit,
            ) = INTEREST_RATE_MODEL.calculateCompoundInterestRateWithOverflowDetection(
                cfg,
                testCase.input.totalDeposits,
                testCase.input.totalBorrowAmount,
                testCase.input.lastTransactionTime,
                testCase.input.currentTime
            );

            address silo = address(uint160(i));

            (, IInterestRateModelV2Config configAddress) = CONFIG_FACTORY.create(_toConfigStruct(testCase));

            vm.prank(silo);
            INTEREST_RATE_MODEL.connect(address(configAddress));

            INTEREST_RATE_MODEL.mockSetup(silo, testCase.input.integratorState, testCase.input.Tcrit);

            vm.warp(testCase.input.currentTime);
            vm.prank(silo);
            INTEREST_RATE_MODEL.getCompoundInterestRateAndUpdate(
                testCase.input.totalDeposits,
                testCase.input.totalBorrowAmount,
                testCase.input.lastTransactionTime
            );

            (int256 storageRi, int256 storageTcrit,)= INTEREST_RATE_MODEL.getSetup(silo);

            assertEq(storageRi, ri, _concatMsg(i, "storageRi"));
            assertEq(storageTcrit, Tcrit, _concatMsg(i, "storageTcrit"));
        }
    }

    function _diff(int256 _a, int256 _b) internal pure returns (uint256 diff) {
        int256 deviation = (_a * int256(BASIS_POINTS)) / _b;
        uint256 positiveDeviation = uint256(deviation < 0 ? -deviation : deviation);

        diff = positiveDeviation > BASIS_POINTS ? positiveDeviation - BASIS_POINTS : BASIS_POINTS - positiveDeviation;
    }

    function _diff(uint256 _a, uint256 _b) internal pure returns (uint256 diff) {
        uint256 positiveDeviation = (_a * BASIS_POINTS) / _b;
        diff = positiveDeviation > BASIS_POINTS ? positiveDeviation - BASIS_POINTS : BASIS_POINTS - positiveDeviation;
    }

    function _concatMsg(uint256 _i, string memory _msg) internal pure returns (string memory) {
        return string.concat("[", Strings.toString(_i), "] ", _msg);
    }
}
