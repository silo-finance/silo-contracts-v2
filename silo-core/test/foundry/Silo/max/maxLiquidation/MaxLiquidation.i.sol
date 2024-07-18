// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

import {MaxLiquidationCommon} from "./MaxLiquidationCommon.sol";

/*
    forge test -vv --ffi --mc MaxLiquidationTest

    this tests are for "normal" case,
    where user became insolvent and we can partially liquidate
*/
contract MaxLiquidationTest is MaxLiquidationCommon {
    using SiloLensLib for ISilo;

    /*
    forge test -vv --ffi --mt test_maxLiquidation_noDebt
    */
    function test_maxLiquidation_noDebt() public {
        _assertBorrowerIsSolvent();

        _depositForBorrow(11e18, borrower);
        _deposit(11e18, borrower);

        _assertBorrowerIsSolvent();
    }

    /*
    forge test -vv --ffi --mt test_maxLiquidation_partial_1token_sTokens_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 10000
    function test_maxLiquidation_partial_1token_sTokens_fuzz(uint128 _collateral) public {
        _maxLiquidation_partial_1token_fuzz(_collateral, _RECEIVE_STOKENS);
    }

    /*
    forge test -vv --ffi --mt test_maxLiquidation_partial_1token_tokens_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 10000
    function test_maxLiquidation_partial_1token_tokens_fuzz(uint128 _collateral) public {
        _maxLiquidation_partial_1token_fuzz(_collateral, !_RECEIVE_STOKENS);
    }

    function _maxLiquidation_partial_1token_fuzz(uint128 _collateral, bool _receiveSToken) internal {
        bool _sameAsset = true;

        // this condition is to not have overflow: _collateral * 85
        vm.assume(_collateral < type(uint128).max / 85);

        vm.assume(_collateral != 29); // dust
        vm.assume(_collateral != 30); // dust
        vm.assume(_collateral != 31); // dust
        vm.assume(_collateral != 32); // dust
        vm.assume(_collateral != 33); // dust
        vm.assume(_collateral != 34); // dust
        vm.assume(_collateral != 35); // dust
        vm.assume(_collateral != 36); // dust
        vm.assume(_collateral != 37); // dust
        vm.assume(_collateral != 38); // dust

        vm.assume(_collateral != 52); // dust
        vm.assume(_collateral != 53); // dust
        vm.assume(_collateral != 54); // dust
        vm.assume(_collateral != 55); // dust
        vm.assume(_collateral != 56); // dust
        vm.assume(_collateral != 57); // dust

        // this value found by fuzzing tests, is high enough to have partial liquidation possible for this test setup
        vm.assume(_collateral >= 20);

        uint256 toBorrow = _collateral * 85 / 100; // maxLT is 85%

        _createDebt(_collateral, toBorrow, _sameAsset);

        vm.warp(block.timestamp + 1050 days); // initial time movement to speed up _moveTimeUntilInsolvent

        _moveTimeUntilInsolvent();

        _assertBorrowerIsNotSolvent({_hasBadDebt: false}); // TODO make tests for bad debt as well

        _executeLiquidationAndRunChecks(_sameAsset, _receiveSToken);

        _assertBorrowerIsSolvent();
        _ensureBorrowerHasDebt();
    }

    /*
    forge test -vv --ffi --mt test_maxLiquidation_partial_2tokens_sTokens_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxLiquidation_partial_2tokens_sTokens_fuzz(uint128 _collateral) public {
        _maxLiquidation_partial_2tokens_fuzz(_collateral, _RECEIVE_STOKENS);
    }

    /*
    forge test -vv --ffi --mt test_maxLiquidation_partial_2tokens_tokens_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxLiquidation_partial_2tokens_tokens_fuzz(uint128 _collateral) public {
        _maxLiquidation_partial_2tokens_fuzz(_collateral, !_RECEIVE_STOKENS);
    }

    function _maxLiquidation_partial_2tokens_fuzz(uint128 _collateral, bool _receiveSToken) internal {
        bool _sameAsset = false;

        vm.assume(_collateral != 12); // dust case
        vm.assume(_collateral != 19); // dust case
        vm.assume(_collateral != 33); // dust

        // this condition is to not have overflow: _collateral * 75
        vm.assume(_collateral < type(uint128).max / 75);
        vm.assume(_collateral >= 7); // LTV100 cases

        uint256 toBorrow = _collateral * 75 / 100; // maxLT is 75%

        _createDebt(_collateral, toBorrow, _sameAsset);

        // for same asset interest increasing slower, because borrower is also depositor, also LT is higher
        _moveTimeUntilInsolvent();

        _assertBorrowerIsNotSolvent({_hasBadDebt: false});

        _executeLiquidationAndRunChecks(_sameAsset, _receiveSToken);

        _assertBorrowerIsSolvent();
        _ensureBorrowerHasDebt();
    }

    function _executeLiquidation(bool _sameToken, bool _receiveSToken)
        internal
        virtual
        override
        returns (uint256 withdrawCollateral, uint256 repayDebtAssets)
    {
        // to test max, we want to provide higher `_debtToCover` and we expect not higher results
        uint256 debtToCover = type(uint256).max;

        (
            uint256 collateralToLiquidate, uint256 debtToRepay
        ) = partialLiquidation.maxLiquidation(address(silo1), borrower);

        emit log_named_decimal_uint("[MaxLiquidation] collateralToLiquidate", collateralToLiquidate, 18);
        emit log_named_decimal_uint("[MaxLiquidation] debtToRepay", debtToRepay, 16);
        emit log_named_decimal_uint("[MaxLiquidation] ltv before", silo0.getLtv(borrower), 16);

        (withdrawCollateral, repayDebtAssets) = partialLiquidation.liquidationCall(
            address(silo1),
            address(_sameToken ? token1 : token0),
            address(token1),
            borrower,
            debtToCover,
            _receiveSToken
        );

        emit log_named_decimal_uint("[MaxLiquidation] ltv after", silo0.getLtv(borrower), 16);

        assertEq(debtToRepay, repayDebtAssets, "debt: maxLiquidation == result");
        _assertEqDiff(withdrawCollateral, collateralToLiquidate, "collateral: max == result");
    }
}
