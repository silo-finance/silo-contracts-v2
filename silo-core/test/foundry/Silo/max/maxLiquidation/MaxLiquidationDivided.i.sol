// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

import {MaxLiquidationTest} from "./MaxLiquidation.i.sol";

/*
    forge test -vv --ffi --mc MaxLiquidationDividedTest

    this tests are MaxLiquidationTest cases, difference is, we splitting max liquidation in chunks
*/
contract MaxLiquidationDividedTest is MaxLiquidationTest {
    using SiloLensLib for ISilo;

    uint256[] private _testCases;

    function _executeLiquidation(bool _sameToken, bool _receiveSToken)
        internal
        override
        returns (uint256 withdrawCollateral, uint256 repayDebtAssets)
    {
        (
            uint256 collateralToLiquidate, uint256 debtToCover
        ) = partialLiquidation.maxLiquidation(address(silo1), borrower);

        _prepareTestCases(debtToCover);

        emit log_named_decimal_uint("[MaxLiquidationDivided] ltv before", silo0.getLtv(borrower), 16);

        uint256 partialCollateral;
        uint256 partialDebt;

        for (uint256 i; i < _testCases.length; i++) {
            emit log_named_uint("[MaxLiquidationDivided] _testCases[i]", _testCases[i]);

            (partialCollateral, partialDebt) = _liquidationCall(_testCases[i], _sameToken, _receiveSToken);
            withdrawCollateral += partialCollateral;
            repayDebtAssets += partialDebt;
        }

        emit log_named_decimal_uint("[MaxLiquidationDivided] ltv after", silo0.getLtv(borrower), 16);
        emit log_named_decimal_uint("[MaxLiquidationDivided] collateralToLiquidate", collateralToLiquidate, 18);

        assertEq(debtToCover, repayDebtAssets, "debt: maxLiquidation == result");
        _assertEqDiff(withdrawCollateral, collateralToLiquidate, "collateral: max == result");
    }

    function _liquidationCall(uint256 _debtToCover, bool _sameToken, bool _receiveSToken)
        private
        returns (uint256 withdrawCollateral, uint256 repayDebtAssets)
    {
        return partialLiquidation.liquidationCall(
            address(silo1),
            address(_sameToken ? token1 : token0),
            address(token1),
            borrower,
            _debtToCover,
            _receiveSToken
        );
    }

    function _prepareTestCases(uint256 _debtToCover) private {
        delete _testCases;

        // min amount of assets that will not generate ZeroShares error
        uint256 minAssets = silo1.previewRepayShares(1);

        _testCases.push(minAssets);
        _debtToCover -= _testCases[_testCases.length - 1];

        if (_debtToCover == 0) return;

        _testCases.push(minAssets);
        _debtToCover -= _testCases[_testCases.length - 1];

        if (_debtToCover == 0) return;

        _testCases.push(_debtToCover /  2);
        _debtToCover -= _testCases[_testCases.length - 1];

        if (_debtToCover == 0) return;

        _testCases.push(_debtToCover - minAssets);
        _debtToCover -= _testCases[_testCases.length - 1];

        if (_debtToCover == 0) return;

        _testCases.push(_debtToCover);
    }
}
