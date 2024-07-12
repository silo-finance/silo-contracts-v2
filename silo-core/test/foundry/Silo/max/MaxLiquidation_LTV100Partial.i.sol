// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

import {MaxLiquidationCommon} from "./MaxLiquidationCommon.sol";

/*
    forge test -vv --ffi --mc MaxLiquidationLTV100PartialTest

    cases where we go from solvent to 100% and we can do partial liquidation
*/
contract MaxLiquidationLTV100PartialTest is MaxLiquidationCommon {
    using SiloLensLib for ISilo;

    /*
    forge test -vv --ffi --mt test_maxLiquidation_LTV100_partial_1token_sTokens_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 100
    function test_maxLiquidation_LTV100_partial_1token_sTokens() public {
        // I did not found cases for this scenario
    }

    /*
    forge test -vv --ffi --mt test_maxLiquidation_LTV100_partial_1token_tokens_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 100
    function test_maxLiquidation_LTV100_partial_1token_tokens() public {
        // // I did not found cases for this scenario
    }

    /*
    forge test -vv --ffi --mt test_maxLiquidation_LTV100_partial_2tokens_sToken_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 100
    function test_maxLiquidation_LTV100_partial_2tokens_sToken_fuzz(uint16 _collateral) public {
        _maxLiquidation_LTV100_partial_2tokens_fuzz(_collateral, _RECEIVE_STOKENS);
    }

    /*
    forge test -vv --ffi --mt test_maxLiquidation_LTV100_partial_2tokens_token_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 100
    function test_maxLiquidation_LTV100_partial_2tokens_token_fuzz(
         uint16 _collateral
    ) public {
        _maxLiquidation_LTV100_partial_2tokens_fuzz(_collateral, !_RECEIVE_STOKENS);
    }

    function _maxLiquidation_LTV100_partial_2tokens_fuzz(uint16 _collateral, bool _receiveSToken) internal {
        bool _sameAsset = false;

        vm.assume(_collateral != 2);
        vm.assume(_collateral < 7);

        uint256 toBorrow = uint256(_collateral) * 75 / 100; // maxLTV is 75%

        _createDebt(_collateral, toBorrow, _sameAsset);

        // this case never happen because is is not possible to create debt for 1 collateral
        if (_collateral == 1) _findLTV100();
        else if (_collateral == 3) vm.warp(66 days);
        else if (_collateral == 4) vm.warp(45 days);
        else if (_collateral == 5) vm.warp(95 days);
        else if (_collateral == 6) vm.warp(66 days);
        else revert("should not happen, because of vm.assume");

        _assertLTV100();

        _executeLiquidationAndChecks(_sameAsset, _receiveSToken);

        _assertBorrowerIsSolvent();
        _ensureBorrowerHasDebt();
    }

    function _executeLiquidationAndChecks(bool _sameToken, bool _receiveSToken) private {
        uint256 siloBalanceBefore0 = token0.balanceOf(address(silo0));
        uint256 siloBalanceBefore1 = token1.balanceOf(address(silo1));

        uint256 liquidatorBalanceBefore0 = token0.balanceOf(address(this));

        (
            uint256 collateralToLiquidate, uint256 debtToRepay
        ) = partialLiquidation.maxLiquidation(address(silo1), borrower);

        (uint256 withdrawCollateral, uint256 repayDebtAssets) = _executeLiquidation(_sameToken, _receiveSToken);

        if (_sameToken) {
            assertEq(
                siloBalanceBefore0,
                token0.balanceOf(address(silo0)),
                "silo0 did not changed, because it is a case for same asset"
            );

            assertEq(
                liquidatorBalanceBefore0,
                token0.balanceOf(address(this)),
                "liquidator balance for token0 did not changed, because it is a case for same asset"
            );

            if (_receiveSToken) {
                assertEq(
                    siloBalanceBefore1 + repayDebtAssets,
                    token1.balanceOf(address(silo1)),
                    "debt was repay to silo but collateral NOT withdrawn"
                );
            } else {
                _assertEqDiff(
                    siloBalanceBefore1 + repayDebtAssets - collateralToLiquidate,
                    token1.balanceOf(address(silo1)),
                    "debt was repay to silo and collateral withdrawn"
                );
            }
        } else {
            if (_receiveSToken) {
                assertEq(
                    siloBalanceBefore0,
                    token0.balanceOf(address(silo0)),
                    "collateral was NOT moved from silo, because we using sToken"
                );

                assertEq(
                    liquidatorBalanceBefore0,
                    token0.balanceOf(address(this)),
                    "collateral was NOT moved to liquidator, because we using sToken"
                );
            } else {
                _assertEqDiff(
                    siloBalanceBefore0 - collateralToLiquidate,
                    token0.balanceOf(address(silo0)),
                    "collateral was moved from silo"
                );

                _assertEqDiff(
                    token0.balanceOf(address(this)),
                    liquidatorBalanceBefore0 + collateralToLiquidate,
                    "collateral was moved to liquidator"
                );
            }

            assertEq(
                siloBalanceBefore1 + repayDebtAssets,
                token1.balanceOf(address(silo1)),
                "debt was repay to silo"
            );
        }
    }

    function _executeLiquidation(bool _sameToken, bool _receiveSToken)
        private
        returns (uint256 withdrawCollateral, uint256 repayDebtAssets)
    {
        // to test max, we want to provide higher `_debtToCover` and we expect not higher results
        uint256 debtToCover = type(uint256).max;

        (
            uint256 collateralToLiquidate, uint256 debtToRepay
        ) = partialLiquidation.maxLiquidation(address(silo1), borrower);

        emit log_named_decimal_uint("[_executeMaxPartialLiquidation] ltv before", silo0.getLtv(borrower), 16);

        // TODO try do liquidate less and then again the rest of debt, will that summ up?
        (withdrawCollateral, repayDebtAssets) = partialLiquidation.liquidationCall(
            address(silo1),
            address(_sameToken ? token1 : token0),
            address(token1),
            borrower,
            debtToCover,
            _receiveSToken
        );

        emit log_named_decimal_uint("[_executeMaxPartialLiquidation] ltv after", silo0.getLtv(borrower), 16);
        emit log_named_decimal_uint("[_executeMaxPartialLiquidation] collateralToLiquidate", collateralToLiquidate, 18);

        assertEq(debtToRepay, repayDebtAssets, "debt: maxLiquidation == result");

        _assertEqDiff(
            withdrawCollateral,
            collateralToLiquidate,
            "collateral: max == result"
        );
    }
}
