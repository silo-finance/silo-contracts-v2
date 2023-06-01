// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "../../contracts/AmmStateModel.sol";
import "./data-readers/AmmStateModelTestData.sol";

/*
    FOUNDRY_PROFILE=amm forge test -vvv --match-contract AmmStateModelTest
*/
contract AmmStateModelTest is Test {
    uint256 public constant ONE = 1e18;
    AmmStateModel public immutable stateModel;
    AmmStateModelTestData public immutable ammStateModelTestData;

    constructor() {
        stateModel = new AmmStateModel();
        ammStateModelTestData = new AmmStateModelTestData();
    }

    /*
        FOUNDRY_PROFILE=amm forge test -vv --match-test test_ammStateModelFlow
    */
    function test_ammStateModelFlow() public {
        AmmStateModelTestData.TestData[] memory testDatas = ammStateModelTestData.testData();

        _ammStateModelFlow(testDatas, false, 427211);
        _ammStateModelFlow(testDatas, true, 393522);
    }

    function _ammStateModelFlow(
        AmmStateModelTestData.TestData[] memory _testDatas,
        bool _withdrawAll,
        uint256 _expectedGas
    ) internal {
        uint256 gasSum;
        assertEq(_testDatas.length, 17, "for proper gas check, update it when add more tests");

        for (uint i; i < _testDatas.length; i++) {
            AmmStateModelTestData.TestData memory testData = _testDatas[i];

            uint256 gasStart = gasleft();

            if (testData.action == AmmStateModelTestData.Action.STATE_CHECK) {
                // state check
            } else if (testData.action == AmmStateModelTestData.Action.ADD_LIQUIDITY) {
                stateModel.addLiquidity(testData.user, testData.price, testData.amount);
            } else if (testData.action == AmmStateModelTestData.Action.SWAP) {
                stateModel.onSwap(testData.amount, testData.amount * testData.price / ONE);
                // data will be tested on state check or other action
                uint256 gasLeft = gasleft();
                gasSum += (gasStart - gasLeft);
                continue;
            } else if (testData.action == AmmStateModelTestData.Action.WITHDRAW) {
                testData.amount == ONE && _withdrawAll
                    ? stateModel.withdrawAllLiquidity(testData.user)
                    : stateModel.withdrawLiquidity(testData.user, testData.amount);
            } else {
                revert("not supported");
            }

            uint256 gasEnd = gasleft();
            gasSum += (gasStart - gasEnd);

            if (i == _testDatas.length - 1) {
                assertTrue(testData.action == AmmStateModelTestData.Action.WITHDRAW, "we need withdraw for last one");
                // assuming we withdraw all already, nothing should happen when withdraw again
                stateModel.withdrawLiquidity(testData.user, 1e18);
            }

            AmmStateModel.TotalState memory state = stateModel.getTotalState();
            AmmStateModel.UserPosition memory userPosition = stateModel.positions(testData.user);

            uint256 userAvailableCollateral = stateModel.getCurrentlyAvailableCollateralForUser(
                state.shares,
                state.availableCollateral,
                userPosition.shares
            );

            uint256 userAvailableDebt = stateModel.userAvailableDebtAmount(
                state.debtAmount,
                state.liquidationTimeValue,
                state.R,
                userPosition,
                userAvailableCollateral
            );

            assertEq(userPosition.collateralAmount, testData.userState.collateralAmount, "user.Ai");
            assertEq(userPosition.liquidationTimeValue, testData.userState.liquidationTimeValue, "user.Vi");
            assertEq(userPosition.shares, testData.userState.shares, "user.Si");
            assertEq(userAvailableCollateral, testData.userState.availableCollateral, "user.Ci");
            assertEq(userAvailableDebt, testData.userState.debtAmount, "user.Di");

            assertEq(state.collateralAmount, testData.totalState.collateralAmount, "total.A");
            assertEq(state.liquidationTimeValue, testData.totalState.liquidationTimeValue, "total.V");
            assertEq(state.shares, testData.totalState.shares, "total.S");
            assertEq(state.availableCollateral, testData.totalState.availableCollateral, "total.C");
            assertEq(state.debtAmount, testData.totalState.debtAmount, "total.D");
            assertEq(state.R, testData.totalState.r, "total.R");
        }

        assertEq(gasSum, _expectedGas, "make sure we gas efficient on price model actions");
    }
}
