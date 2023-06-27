// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "./data-readers/AmmStateModelTestData.sol";
import "./helpers/StateModel.sol";
import "../../contracts/AmmStateModel.sol";


/*
    FOUNDRY_PROFILE=amm-core forge test -vv --match-contract AmmStateModelTest
*/
contract AmmStateModelTest is Test {
    address public constant COLLATERAL = address(123);
    uint256 public constant ONE = 1e18;
    StateModel public immutable stateModel;
    AmmStateModelTestData public immutable ammStateModelTestData;

    mapping (AmmStateModelTestData.Action => uint[]) gas;

    constructor() {
        stateModel = new StateModel(COLLATERAL);
        ammStateModelTestData = new AmmStateModelTestData();
    }

    /*
        FOUNDRY_PROFILE=amm-core forge test -vv --match-test test_ammStateModelFlow
    */
    function test_ammStateModelFlow() public {
        AmmStateModelTestData.TestData[] memory testDatas = ammStateModelTestData.testData();

        _ammStateModelFlow(testDatas, false, 438051);
        _ammStateModelFlow(testDatas, true, 401166);
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

            if (testData.action == AmmStateModelTestData.Action.STATE_CHECK) {
                // state check
            } else if (testData.action == AmmStateModelTestData.Action.ADD_LIQUIDITY) {
                uint256 collateralValue = testData.price * testData.amount / ONE;
                uint256 gasStart = gasleft();
                stateModel.addLiquidity(testData.user, testData.amount, collateralValue);
                uint256 gasLeft = gasleft();
                gasSum += _saveGas(AmmStateModelTestData.Action.ADD_LIQUIDITY, gasStart - gasLeft);
            } else if (testData.action == AmmStateModelTestData.Action.SWAP) {
                uint256 gasStart = gasleft();
                stateModel.onSwapStateChange(testData.amount, testData.amount * testData.price / ONE);
                // data will be tested on state check or other action
                uint256 gasLeft = gasleft();
                gasSum += _saveGas(AmmStateModelTestData.Action.SWAP, gasStart - gasLeft);
                continue;
            } else if (testData.action == AmmStateModelTestData.Action.WITHDRAW) {
                uint256 gasStart = gasleft();

                testData.amount == ONE && _withdrawAll
                    ? stateModel.withdrawAllLiquidity(testData.user)
                    : stateModel.withdrawLiquidity(testData.user, testData.amount);

                uint256 gasLeft = gasleft();
                gasSum += _saveGas(AmmStateModelTestData.Action.WITHDRAW, gasStart - gasLeft);
            } else {
                revert("not supported");
            }

            if (i == _testDatas.length - 1) {
                assertTrue(testData.action == AmmStateModelTestData.Action.WITHDRAW, "we need withdraw for last one");
                // assuming we withdraw all already, nothing should happen when withdraw again
                uint256 gasStart = gasleft();
                stateModel.withdrawLiquidity(testData.user, 1e18);
                uint256 gasLeft = gasleft();
                gasSum += _saveGas(AmmStateModelTestData.Action.WITHDRAW, gasStart - gasLeft);
            }

            AmmStateModel.TotalState memory state = stateModel.getTotalState(COLLATERAL);
            AmmStateModel.UserPosition memory userPosition = stateModel.positions(COLLATERAL, testData.user);

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

        _printGas();
    }

    function _saveGas(AmmStateModelTestData.Action _action, uint256 _gasUsed) internal returns (uint256 gasUsed) {
        gas[_action].push(_gasUsed);
        return _gasUsed;
    }

    function _printGas() internal {
        emit log("ADD_LIQUIDITY");
        _printGasAction(AmmStateModelTestData.Action.ADD_LIQUIDITY);
        emit log("SWAP");
        _printGasAction(AmmStateModelTestData.Action.SWAP);
        emit log("WITHDRAW");
        _printGasAction(AmmStateModelTestData.Action.WITHDRAW);
    }

    function _printGasAction(AmmStateModelTestData.Action _action) internal {
        uint256 count = gas[_action].length;

        for (uint i; i < count; i++) {
            emit log_named_uint("gas used", gas[_action][i]);
        }
    }
}
