// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

import {MaxLiquidationTest} from "./MaxLiquidation.i.sol";

/*
    forge test -vv --ffi --mc MaxLiquidationWithChunksTest

    this tests are MaxLiquidationTest cases, difference is, we splitting max liquidation in chunks
*/
contract MaxLiquidationWithChunksTest is MaxLiquidationTest {
    using SiloLensLib for ISilo;

    function _executeLiquidation(bool _sameToken, bool _receiveSToken)
        internal
        override
        returns (uint256 withdrawCollateral, uint256 repayDebtAssets)
    {
        (
            uint256 totalCollateralToLiquidate, uint256 totalDebtToCover
        ) = partialLiquidation.maxLiquidation(address(silo1), borrower);

        emit log_named_decimal_uint("[MaxLiquidationWithChunks] ltv before", silo0.getLtv(borrower), 16);

        for (uint256 i; i < 5; i++) {
            emit log_named_uint("[MaxLiquidationWithChunks] case ------------------------", i);
            bool isSolvent = silo0.isSolvent(borrower);

            emit log_named_string("isSolvent", silo0.isSolvent(borrower) ? "YES" : "NO");
            emit log_named_decimal_uint("[MaxLiquidationWithChunks] ltv before", silo0.getLtv(borrower), 16);

            (
                uint256 collateralToLiquidate, uint256 debtToCover
            ) = partialLiquidation.maxLiquidation(address(silo1), borrower);
            emit log_named_uint("[MaxLiquidationWithChunks] max collateralToLiquidate", collateralToLiquidate);
            emit log_named_uint("[MaxLiquidationWithChunks] max debtToCover", debtToCover);

            // this conditions caught bug
            if (isSolvent && debtToCover != 0) revert("if we solvent there should be no liquidation");
            if (!isSolvent && debtToCover == 0) revert("if we NOT solvent there should be a liquidation");

            if (isSolvent) break;

            uint256 testDebtToCover = _calculateChunk(debtToCover, i);
            emit log_named_uint("[MaxLiquidationWithChunks] testDebtToCover", testDebtToCover);

            (
                uint256 partialCollateral, uint256 partialDebt
            ) = _liquidationCall(testDebtToCover, _sameToken, _receiveSToken);
            emit log_named_uint("[MaxLiquidationWithChunks] partialCollateral", partialCollateral);
            emit log_named_uint("[MaxLiquidationWithChunks] partialDebt", partialDebt);

            withdrawCollateral += partialCollateral;
            repayDebtAssets += partialDebt;

            _assertLeDiff(partialCollateral, collateralToLiquidate, "partialCollateral");

            // TODO warp?
        }

        emit log_named_decimal_uint("[MaxLiquidationWithChunks] ltv after all chunks", silo0.getLtv(borrower), 16);

        // sum of chunk liquidation can be smaller than one max/total, because with chunks we can get to the point
        // where user became solvent and the margin we have for max liquidation will not be used
        assertLe(repayDebtAssets, totalDebtToCover, "chunks(debt) can not be bigger than total/max");

        _assertLeDiff(
            withdrawCollateral,
            totalCollateralToLiquidate,
            "chunks(collateral) can not be bigger than total/max"
        );
    }
}
