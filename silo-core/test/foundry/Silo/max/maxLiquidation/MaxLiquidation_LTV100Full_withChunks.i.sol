// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {MaxLiquidationLTV100FullTest} from "./MaxLiquidation_LTV100Full.i.sol";

/*
    forge test -vv --ffi --mc MaxLiquidationLTV100FullWithChunksTest

    this tests are MaxLiquidationLTV100FullWith cases, difference is, we splitting max liquidation in chunks
*/
contract MaxLiquidationLTV100FullWithChunksTest is MaxLiquidationLTV100FullTest {
    using SiloLensLib for ISilo;

    // this is copy of method from MaxLiquidationLTV100FullTest but without `_ensureBorrowerHasNoDebt` check
    // because when we liquidate with chunks, we can end up with debt but being solvent
    function _maxLiquidation_LTV100_full_1token_fuzz(uint8 _collateral, bool _receiveSToken) internal override {
        bool _sameAsset = true;

        vm.assume(_collateral < 20);
        uint256 toBorrow = uint256(_collateral) * 85 / 100;

        _createDebt(_collateral, toBorrow, _sameAsset);

        // case for `1` never happen because is is not possible to create debt for 1 collateral
        if (_collateral == 1) _findLTV100();
        else if (_collateral == 2) vm.warp(7229 days);
        else if (_collateral == 3) vm.warp(3172 days);
        else if (_collateral == 4) vm.warp(2001 days);
        else if (_collateral == 5) vm.warp(1455 days);
        else if (_collateral == 6) vm.warp(1141 days);
        else if (_collateral == 7) vm.warp(2457 days);
        else if (_collateral == 8) vm.warp(2001 days);
        else if (_collateral == 9) vm.warp(1685 days);
        else if (_collateral == 10) vm.warp(1455 days);
        else if (_collateral == 11) vm.warp(1279 days);
        else if (_collateral == 12) vm.warp(1141 days);
        else if (_collateral == 13) vm.warp(1030 days);
        else if (_collateral == 14) vm.warp(2059 days);
        else if (_collateral == 15) vm.warp(1876 days);
        else if (_collateral == 16) vm.warp(1722 days);
        else if (_collateral == 17) vm.warp(1592 days);
        else if (_collateral == 18) vm.warp(1480 days);
        else if (_collateral == 19) vm.warp(1382 days);
        else revert("should not happen, because of vm.assume");

        _assertLTV100();

        _executeLiquidationAndChecks(_sameAsset, _receiveSToken);

        _assertBorrowerIsSolvent();
    }

    function _executeLiquidation(bool _sameToken, bool _receiveSToken)
        internal
        override
        returns (uint256 withdrawCollateral, uint256 repayDebtAssets)
    {
        (
            uint256 totalCollateralToLiquidate, uint256 totalDebtToCover
        ) = partialLiquidation.maxLiquidation(address(silo1), borrower);

        emit log_named_decimal_uint("[LTV100FullWithChunks] ltv before", silo0.getLtv(borrower), 16);

        for (uint256 i; i < 5; i++) {
            emit log_named_uint("[LTV100FullWithChunks] case ------------------------", i);
            bool isSolvent = silo0.isSolvent(borrower);

            emit log_named_string("isSolvent", silo0.isSolvent(borrower) ? "YES" : "NO");

            (
                uint256 collateralToLiquidate, uint256 debtToCover
            ) = partialLiquidation.maxLiquidation(address(silo1), borrower);

            emit log_named_uint("[LTV100FullWithChunks] debtToCover", debtToCover);

            if (isSolvent && debtToCover != 0) revert("if we solvent there should be no liquidation");
            if (!isSolvent && debtToCover == 0) revert("if we NOT solvent there should be a liquidation");

            if (isSolvent) break;

            uint256 testDebtToCover = _calculateChunk(debtToCover, i);
            emit log_named_uint("[LTV100FullWithChunks] testDebtToCover", testDebtToCover);

            (
                uint256 partialCollateral, uint256 partialDebt
            ) = _liquidationCall(testDebtToCover, _sameToken, _receiveSToken);

            _assertLeDiff(partialCollateral, collateralToLiquidate, "partialCollateral");

            withdrawCollateral += partialCollateral;
            repayDebtAssets += partialDebt;
        }

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
