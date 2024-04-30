// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Strings} from "openzeppelin5/utils/Strings.sol";

import "silo-core/contracts/interestRateModel/InterestRateModelV2.sol";
import "silo-core/contracts/interestRateModel/InterestRateModelV2ConfigFactory.sol";

import "./InterestRateModelV2Impl.sol";
import "../_common/InterestRateModelConfigs.sol";
import "../data-readers/RcurTestData.sol";
import "../../../contracts/interestRateModel/InterestRateModelV2ConfigFactory.sol";
import "../../../contracts/interfaces/IInterestRateModelV2Config.sol";

// forge test -vv --mc InterestRateModelV2RcurTest
contract InterestRateModelV2RcurTest is RcurTestData, InterestRateModelConfigs {
    InterestRateModelV2ConfigFactory immutable CONFIG_FACTORY;
    InterestRateModelV2Impl immutable INTEREST_RATE_MODEL;

    uint256 constant DP = 10 ** 18;
    uint256 constant BASIS_POINTS = 10000;

    constructor() {
        INTEREST_RATE_MODEL = new InterestRateModelV2Impl();
        CONFIG_FACTORY = new InterestRateModelV2ConfigFactory();
    }

    /*
    forge test -vv --mt test_IRM_RcurData
    */
    function test_IRM_RcurData() public {
        RcurData[] memory data = _readDataFromJson();

        for (uint256 i; i < data.length; i++) {
            RcurData memory testCase = data[i];

            IInterestRateModelV2.ConfigWithState memory cfg = _toConfigWithState(testCase);

            uint256 rcur = INTEREST_RATE_MODEL.calculateCurrentInterestRate(
                cfg,
                testCase.input.totalDeposits,
                testCase.input.totalBorrowAmount,
                testCase.input.lastTransactionTime,
                testCase.input.currentTime
            );

            if (testCase.expected.currentAnnualInterest == 0) {
                assertEq(rcur, testCase.expected.currentAnnualInterest, _concatMsg(i, "currentAnnualInterest"));
            } else {
                uint256 deviation = (rcur * BASIS_POINTS) / testCase.expected.currentAnnualInterest;
                uint256 diff = deviation > BASIS_POINTS ? deviation - BASIS_POINTS : BASIS_POINTS - deviation;

                // allow maximum of 0.01% (1bps) deviation between high precision test results and smart contracts output
                assertLe(diff, 1, _concatMsg(i, "allow maximum of 0.01% (1bps) deviation"));
            }

            ISilo.UtilizationData memory utilizationData = ISilo.UtilizationData(
                testCase.input.totalDeposits,
                testCase.input.totalBorrowAmount,
                uint64(testCase.input.lastTransactionTime)
            );

            address silo = address(uint160(i));

            (, IInterestRateModelV2Config configAddress) = CONFIG_FACTORY.create(_toConfigStruct(testCase));

            vm.prank(silo);
            INTEREST_RATE_MODEL.connect(address(configAddress));

            INTEREST_RATE_MODEL.mockSetup(silo, testCase.input.integratorState, testCase.input.Tcrit);

            bytes memory encodedData = abi.encodeWithSelector(ISilo.utilizationData.selector);
            vm.mockCall(silo, encodedData, abi.encode(utilizationData));
            vm.expectCall(silo, encodedData);

            uint256 mockedRcur = INTEREST_RATE_MODEL.getCurrentInterestRate(silo, testCase.input.currentTime);
            assertEq(mockedRcur, rcur, _concatMsg(i, "getCurrentInterestRate()"));

            bool overflow = INTEREST_RATE_MODEL.overflowDetected(silo, testCase.input.currentTime);
            assertEq(overflow, testCase.expected.didOverflow == 1, _concatMsg(i, "expect overflowDetected() = expected.didOverflow"));
        }
    }

    function _concatMsg(uint256 _i, string memory _msg) internal pure returns (string memory) {
        return string.concat("[", Strings.toString(_i), "] ", _msg);
    }
}
