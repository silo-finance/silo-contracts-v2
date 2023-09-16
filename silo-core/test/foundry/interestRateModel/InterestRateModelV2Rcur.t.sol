// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../../../contracts/interestRateModel/InterestRateModelV2.sol";
import "../_common/InterestRateModelConfigs.sol";
import "../data-readers/RcurTestData.sol";
import "../../../contracts/interestRateModel/InterestRateModelV2ConfigFactory.sol";

contract InterestRateModelV2Impl is InterestRateModelV2 {
    function mockSetup(address _silo, address _asset, int256 _ri, int256 _Tcrit) external {
        getSetup[_silo][_asset].Tcrit = _Tcrit;
        getSetup[_silo][_asset].ri = _ri;
    }
}

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

        for (uint i; i < data.length; i++) {
            RcurData memory testCase = data[i];

            IInterestRateModel.ConfigWithState memory cfg = _toConfigWithState(testCase);

            uint256 rcur = INTEREST_RATE_MODEL.calculateCurrentInterestRate(
                cfg,
                testCase.input.totalDeposits,
                testCase.input.totalBorrowAmount,
                testCase.input.lastTransactionTime,
                testCase.input.currentTime
            );

            if (testCase.expected.currentAnnualInterest == 0) {
                assertEq(rcur, testCase.expected.currentAnnualInterest, "currentAnnualInterest");
            } else {
                uint256 deviation = (rcur * BASIS_POINTS) / testCase.expected.currentAnnualInterest;
                uint256 diff = deviation > BASIS_POINTS ? deviation - BASIS_POINTS : BASIS_POINTS - deviation;

                // allow maximum of 0.01% (1bps) deviation between high precision test results and smart contracts output
                assertLe(diff, 1, "allow maximum of 0.01% (1bps) deviation");
            }

            ISilo.UtilizationData memory utilizationData = ISilo.UtilizationData(
                testCase.input.totalDeposits,
                testCase.input.totalBorrowAmount,
                uint64(testCase.input.lastTransactionTime)
            );

            address silo = address(uint160(i));
            address asset = address(1234567890);

            (, InterestRateModelV2Config configAddress) = CONFIG_FACTORY.create(_toConfigStruct(testCase));

            vm.prank(silo);
            INTEREST_RATE_MODEL.connect(asset, address(configAddress));

            INTEREST_RATE_MODEL.mockSetup(silo, asset, testCase.input.integratorState, testCase.input.Tcrit);
            vm.mockCall(silo, abi.encodeWithSelector(ISilo.utilizationData.selector), abi.encode(utilizationData));
            uint256 mockedRcur = INTEREST_RATE_MODEL.getCurrentInterestRate(silo, asset, testCase.input.currentTime);
            assertEq(mockedRcur, rcur, "getCurrentInterestRate()");

            bool overflow = INTEREST_RATE_MODEL.overflowDetected(silo, asset, testCase.input.currentTime);
            assertEq(overflow, testCase.expected.didOverflow == 1, "expect overflowDetected() = expected.didOverflow");
        }
    }
}
