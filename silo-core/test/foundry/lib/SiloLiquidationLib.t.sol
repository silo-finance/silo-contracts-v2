// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../../contracts/lib/SiloLiquidationLib.sol";

// forge test -vv --mc SiloLiquidationLibTest
contract SiloLiquidationLibTest is Test {
    // forge test -vv --mt test_SiloLiquidationLib_unchecked
    function test_SiloLiquidationLib_unchecked(
        uint128 _debtAmount,
        uint128 _collateralAmount,
        uint16 _targetLT,
        uint16 _liquidityFee,
        uint16 _dustThreshold
    ) public {
        vm.assume(_targetLT <= 1e4);
        vm.assume(_liquidityFee <= 1e3);
        vm.assume(_dustThreshold <= 1e4);

        // prices here are arbitrary
        uint256 debtValue = uint256(_debtAmount) * 50_000;
        uint256 collateralValue = uint256(_collateralAmount) * 80_000;

        // we should not revert because of above assumptions
        SiloLiquidationLib.liquidateValuesVerification(_targetLT, _liquidityFee, _dustThreshold);

        (uint256 repayValue, uint256 receiveCollateral) = SiloLiquidationLib.calculateMaxLiquidationValues(
            debtValue,
            collateralValue,
            uint256(_targetLT),
            uint256(_liquidityFee),
            uint256(_dustThreshold)
        );

        emit log_string("SiloLiquidationLib.calculateLiquidationValues PASS");

        (
            uint256 repayValue2, uint256 receiveCollateral2
        ) = _calculateLiquidationValuesWithCheckedMath(
            debtValue, collateralValue, _targetLT, _liquidityFee, _dustThreshold
        );

        assertEq(repayValue, repayValue2, "repay must match value with safe math");
        assertEq(receiveCollateral, receiveCollateral2, "receiveCollateral must match value with safe math");
    }

    function _calculateLiquidationValuesWithCheckedMath(
        uint256 _debtValue,
        uint256 _collateralValue,
        uint256 _targetLTinBP,
        uint256 _liquidityFeeInBP,
        uint256 _dustThresholdInBP
    )
        internal
        pure
        returns (uint256 receiveCollateralValue, uint256 repayValue)
    {
        if (_debtValue == 0) {
            return (0, 0);
        }

        // this will cover case when _collateralValue == 0
        if (_targetLTinBP == 0 || _debtValue >= _collateralValue) {
            return (_collateralValue, _debtValue);
        }

        uint256 basisPoints = 1e4; // 100%
        uint256 fullFeeInBP;
        { fullFeeInBP = basisPoints + _liquidityFeeInBP; }

        uint256 LTWithFeeInBP;
        { LTWithFeeInBP = _targetLTinBP * fullFeeInBP / basisPoints; }

        // if we over 100% with fee, then we return all
        if (LTWithFeeInBP >= basisPoints) {
            return (_collateralValue, _debtValue);
        }

        { LTWithFeeInBP = basisPoints - LTWithFeeInBP; }

        uint256 targetLT_X_Collateral = _targetLTinBP * _collateralValue / basisPoints;

        if (_debtValue < targetLT_X_Collateral) {
            return (_collateralValue, _debtValue);
        }

        { repayValue = (_debtValue - targetLT_X_Collateral) / LTWithFeeInBP; }

        if (repayValue / _debtValue > _dustThresholdInBP) {
            return (_debtValue, _collateralValue);
        }

        receiveCollateralValue = repayValue * fullFeeInBP;
        { receiveCollateralValue /= basisPoints; }
    }
}
