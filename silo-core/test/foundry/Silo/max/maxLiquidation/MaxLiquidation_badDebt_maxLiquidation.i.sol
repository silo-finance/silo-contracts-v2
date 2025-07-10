// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {MaxLiquidationBadDebtWithChunksTest} from "./MaxLiquidation_badDebt_withChunks.i.sol";

/*
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mc MaxLiquidationBadDebtMaxLiquidationTest

    we testing here the case for bad debt with the same token
*/
contract MaxLiquidationBadDebtMaxLiquidationTest is MaxLiquidationBadDebtWithChunksTest {
    using SiloLensLib for ISilo;

    bool private constant _BAD_DEBT = true;

    /*
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_maxLiquidation_sameAsset_badDebt_investigateCase
    */
    /// forge-config: core_test.fuzz.runs = 10000
    function test_maxLiquidation_sameAsset_badDebt_investigateCase_fuzz(
        uint128 _collateral, uint64 _warp
    ) public {
//        (uint128 _collateral, uint64 _warp) = (287062504436733, 7854163971367945);

        _maxLiquidation_full_1token({_collateral: _collateral, _receiveSToken: false, _warp: _warp});
    }

    function _maxLiquidation_partial_2tokens(uint128 _collateral, bool _receiveSToken) internal virtual override {
        // not needed for this case
    }

    function _maxLiquidation_partial_1token(uint128 _collateral, bool _receiveSToken) internal override {
        // not needed for this case
    }

    function _maxLiquidation_full_1token(uint128 _collateral, bool _receiveSToken, uint64 _warp) internal {
        bool sameAsset = true;

        _createDebtForBorrower(_collateral, sameAsset);

        // we want high interest
        vm.startPrank(borrower);
        uint256 maxWithdraw = silo1.maxWithdraw(borrower);
        if (maxWithdraw != 0) silo1.withdraw(maxWithdraw, borrower, borrower);
        vm.stopPrank();

        vm.assume(block.timestamp + _warp < type(uint64).max);
        vm.warp(block.timestamp + _warp); // initial time movement to speed up _moveTimeUntilInsolvent

        _moveTimeUntilBadDebt();

        _assertBorrowerIsNotSolvent(_BAD_DEBT);

        _executeLiquidationAndRunChecks(sameAsset, _receiveSToken);
    }

    function _maxLiquidation_full_1token(uint128 _collateral, bool _receiveSToken, uint64 _warp) internal {
        bool sameAsset = true;

        _createDebtForBorrower(_collateral, sameAsset);

        // we want high interest
        vm.startPrank(borrower);
        uint256 maxWithdraw = silo1.maxWithdraw(borrower);
        if (maxWithdraw != 0) silo1.withdraw(maxWithdraw, borrower, borrower);
        vm.stopPrank();

        vm.assume(block.timestamp + _warp < type(uint64).max);
        vm.warp(block.timestamp + _warp); // initial time movement to speed up _moveTimeUntilInsolvent

        _moveTimeUntilBadDebt();

        _assertBorrowerIsNotSolvent(_BAD_DEBT);

        _executeLiquidationAndRunChecks(sameAsset, _receiveSToken);
    }

    function _executeLiquidation(bool _sameToken, bool _receiveSToken)
        internal
        override
        returns (uint256 withdrawCollateral, uint256 repayDebtAssets)
    {

        uint256 totalCollateralToLiquidate;
        uint256 totalDebtToCover;

        emit log_named_decimal_uint("[SameAssetBadDebt] ltv before", silo0.getLtv(borrower), 16);
        emit log_named_uint("[SameAssetBadDebt] totalCollateralToLiquidate", totalCollateralToLiquidate);
        emit log_named_uint("[SameAssetBadDebt] totalDebtToCover", totalDebtToCover);

        emit log_named_decimal_uint("ltv", silo0.getLtv(borrower), 16);

        if (silo0.getLtv(borrower) <= 1e18) return(0,0); // not bad debt anymore

        { // too deep
            bool isSolvent = silo0.isSolvent(borrower);
            emit log_named_string("isSolvent", isSolvent ? "YES" : "NO");

            if (isSolvent) return (0,0);
        }

        emit log_named_uint("[SameAssetBadDebt] collateralBalanceOfUnderlying", siloLens.collateralBalanceOfUnderlying(silo1, borrower));
        emit log_named_uint("[SameAssetBadDebt] debtBalanceOfUnderlying", siloLens.debtBalanceOfUnderlying(silo1, borrower));
        emit log_named_uint("[SameAssetBadDebt] total(collateral).assets", silo1.getTotalAssetsStorage(ISilo.AssetType.Collateral));
        emit log_named_uint("[SameAssetBadDebt] getCollateralAssets()", silo1.getCollateralAssets());

        emit log("\t\t =================== maxLiquidation");

        try partialLiquidation.maxLiquidation(borrower)
            returns (uint256 _totalCollateralToLiquidate, uint256 _totalDebtToCover, bool)
        {
            totalCollateralToLiquidate = _totalCollateralToLiquidate;
            totalDebtToCover = _totalDebtToCover;
        } catch {
            // we don't want case when we overflow
            vm.assume(false);
        }

        if (totalCollateralToLiquidate == 0) {
            assertGt(silo0.getLtv(borrower), 1e18, "when no collateral we expect bad debt");
        }

        uint256 testDebtToCover = totalDebtToCover;
        emit log_named_uint("[SameAssetBadDebt] testDebtToCover", testDebtToCover);
        emit log_named_uint("[SameAssetBadDebt] ratio", silo1.convertToAssets(1e18));
        emit log("\t\t =================== _liquidationCall");

        (withdrawCollateral, repayDebtAssets) = _liquidationCall(testDebtToCover, _sameToken, _receiveSToken);

        emit log_named_uint("[SameAssetBadDebt] withdrawCollateral", withdrawCollateral);
        emit log_named_uint("[SameAssetBadDebt] repayDebtAssets", repayDebtAssets);

        assertGe(withdrawCollateral, totalCollateralToLiquidate, "expect no overestimation on maxLiquidation method");

        emit log_named_decimal_uint("[SameAssetBadDebt] final ltv", silo0.getLtv(borrower), 16);
    }

    function _withChunks() internal pure override returns (bool) {
        return false;
    }
}
