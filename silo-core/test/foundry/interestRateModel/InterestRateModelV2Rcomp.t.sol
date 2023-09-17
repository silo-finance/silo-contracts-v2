// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../../../contracts/interestRateModel/InterestRateModelV2.sol";
import "../_common/InterestRateModelConfigs.sol";
import "../data-readers/RcompTestData.sol";
import "../../../contracts/interestRateModel/InterestRateModelV2ConfigFactory.sol";

contract InterestRateModelV2Impl is InterestRateModelV2 {
    function mockSetup(address _silo, int256 _ri, int256 _Tcrit) external {
        getSetup[_silo].Tcrit = _Tcrit;
        getSetup[_silo].ri = _ri;
    }
}

// forge test -vv --mc InterestRateModelV2RcurTest
contract InterestRateModelV2RcompTest is RcompTestData, InterestRateModelConfigs {
    InterestRateModelV2ConfigFactory immutable CONFIG_FACTORY;
    InterestRateModelV2Impl immutable INTEREST_RATE_MODEL;

    uint256 constant DP = 10 ** 18;
    uint256 constant BASIS_POINTS = 10000;

    constructor() {
        INTEREST_RATE_MODEL = new InterestRateModelV2Impl();
        CONFIG_FACTORY = new InterestRateModelV2ConfigFactory();
    }

    // forge test -vv --mt test_IRM_RcompData_Mock
    function test_IRM_RcompData_Mock() public {
        RcompData[] memory data = _readDataFromJson();

        for (uint i; i < data.length; i++) {
            RcompData memory testCase = data[i];

            IInterestRateModel.ConfigWithState memory cfg = _toConfigWithState(testCase);

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

            assertEq(overflow, testCase.expected.didOverflow == 1, "didOverflow");

            if (testCase.expected.compoundInterest == 0) {
                assertEq(rcomp, testCase.expected.compoundInterest, "compoundInterest");
            } else {
                uint256 diff = _diff(rcomp, testCase.expected.compoundInterest);

                // allow maximum of 0.25% (25bps) deviation between high precision test results and smart contracts output
                assertLe(diff, 25, "[rcomp] allow maximum of 0.25% (25bps) ");
            }

            if (testCase.expected.newIntegratorState == 0) {
                assertEq(ri, testCase.expected.newIntegratorState, "newIntegratorState");
            } else {
                uint256 diff = _diff(ri, testCase.expected.newIntegratorState);

                // allow maximum of 0.25% (25bps) deviation between high precision test results and smart contracts output
                assertLe(diff, 25, "[ri] allow maximum of 0.25% (25bps) ");
            }

            if (testCase.expected.newTcrit == 0) {
                assertEq(Tcrit, testCase.expected.newTcrit, "newTcrit");
            } else {
                uint256 diff = _diff(Tcrit, testCase.expected.newTcrit);

                // allow maximum of 0.25% (25bps) deviation between high precision test results and smart contracts output
                assertLe(diff, 25, "[newTcrit] allow maximum of 0.25% (25bps) ");
            }

            ISilo.UtilizationData memory utilizationData = ISilo.UtilizationData(
                testCase.input.totalDeposits,
                testCase.input.totalBorrowAmount,
                uint64(testCase.input.lastTransactionTime)
            );

            address silo = address(uint160(i));

            (, InterestRateModelV2Config configAddress) = CONFIG_FACTORY.create(_toConfigStruct(testCase));

            vm.prank(silo);
            INTEREST_RATE_MODEL.connect(address(configAddress));

            INTEREST_RATE_MODEL.mockSetup(silo, testCase.input.integratorState, testCase.input.Tcrit);
            vm.mockCall(silo, abi.encodeWithSelector(ISilo.utilizationData.selector), abi.encode(utilizationData));
            uint256 compoundInterestRate = INTEREST_RATE_MODEL.getCompoundInterestRate(silo, testCase.input.currentTime);
            assertEq(compoundInterestRate, rcomp, "getCompoundInterestRate()");
        }
    }

    // forge test -vv --mt test_IRM_RcompData_Update
    function test_IRM_RcompData_Update() public {
        RcompData[] memory data = _readDataFromJson();

        for (uint i; i < data.length; i++) {
            RcompData memory testCase = data[i];

            IInterestRateModel.ConfigWithState memory cfg = _toConfigWithState(testCase);

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

            (, InterestRateModelV2Config configAddress) = CONFIG_FACTORY.create(_toConfigStruct(testCase));

            vm.prank(silo);
            INTEREST_RATE_MODEL.connect(address(configAddress));

            ISilo.UtilizationData memory utilizationData = ISilo.UtilizationData(
                testCase.input.totalDeposits,
                testCase.input.totalBorrowAmount,
                uint64(testCase.input.lastTransactionTime)
            );

            INTEREST_RATE_MODEL.mockSetup(silo, testCase.input.integratorState, testCase.input.Tcrit);

            vm.mockCall(silo, abi.encodeWithSelector(ISilo.utilizationData.selector), abi.encode(utilizationData));

            vm.prank(silo);
            INTEREST_RATE_MODEL.getCompoundInterestRateAndUpdate(testCase.input.currentTime);
            (, int256 storageRi, int256 storageTcrit)= INTEREST_RATE_MODEL.getSetup(silo);

            assertEq(storageRi, ri, "storageRi");
            assertEq(storageTcrit, Tcrit, "storageTcrit");
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
}
