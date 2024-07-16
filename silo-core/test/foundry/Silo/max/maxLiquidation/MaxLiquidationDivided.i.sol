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
            uint256 totalCollateralToLiquidate, uint256 totalDebtToCover
        ) = partialLiquidation.maxLiquidation(address(silo1), borrower);

        emit log_named_decimal_uint("[MaxLiquidationDivided] ltv before", silo0.getLtv(borrower), 16);

        for (uint256 i; i < 5; i++) {
            emit log_named_uint("[MaxLiquidationDivided] case ------------------------", i);
            bool isSolvent = silo0.isSolvent(borrower);

            emit log_named_string("isSolvent", silo0.isSolvent(borrower) ? "YES" : "NO");

            (
                uint256 collateralToLiquidate, uint256 debtToCover
            ) = partialLiquidation.maxLiquidation(address(silo1), borrower);

            // this conditions caught bug
            if (isSolvent && debtToCover != 0) revert("if we solvent there should be no liquidation");
            if (!isSolvent && debtToCover == 0) revert("if we NOT solvent there should be a liquidation");

            if (isSolvent) break;

            uint256 testDebtToCover = _prepareTestCase(debtToCover, i);

            (uint256 partialCollateral, uint256 partialDebt) = _liquidationCall(testDebtToCover, _sameToken, _receiveSToken);
            withdrawCollateral += partialCollateral;
            repayDebtAssets += partialDebt;

            // TODO warp?
        }

        // sum of chunk liquidation will be always smaller than one max, because with chunks we will get to the point
        // where user became solvent and the margin we have for max liquidation will not be used
        assertLt(repayDebtAssets, totalDebtToCover, "chunks(debt) are always smaller than total/max");
        assertLt(withdrawCollateral, totalCollateralToLiquidate, "chunks(collateral) are always smaller than total/max");
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

    function _prepareTestCase(uint256 _debtToCover, uint256 _i) private returns (uint256 _chunk) {
        if (_debtToCover == 0) return 0;

        if (_i < 2 || _i == 4) {
            // two first iteration and last one (we assume we have max 5 iterations), try to use minimal amount

            // min amount of assets that will not generate ZeroShares error
            uint256 minAssets = silo1.previewRepayShares(1);

            if (_debtToCover < minAssets) {
                revert("calculation of maxDebtToCover should never return assets that will generate zero shares");
            }

            return minAssets;
        } else if (_i == 2) {
            return _debtToCover / 2;
        } else if (_i == 3) {
            uint256 minAssets = silo1.previewRepayShares(1);
            return _debtToCover < minAssets ? minAssets : _debtToCover - minAssets; // TODO possible? correct?
        } else revert("this should never happen");
    }
}
