// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";

import {MintableToken} from "../../_common/MintableToken.sol";
import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc MaxRepayTest
*/
contract MaxLiquidationTest is SiloLittleHelper, Test {
    using SiloLensLib for ISilo;
    bool internal constant _RECEIVE_STOKENS = true;

    ISiloConfig siloConfig;
    address immutable depositor;
    address immutable borrower;

    constructor() {
        depositor = makeAddr("Depositor");
        borrower = makeAddr("Borrower");
    }

    function setUp() public {
        siloConfig = _setUpLocalFixture(SiloConfigsNames.LOCAL_NO_ORACLE_SILO);
        token1.setOnDemand(true);
    }

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
    forge test -vv --ffi --mt test_maxLiquidation_partial_LTV100_1token_sTokens_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 100
    function test_maxLiquidation_partial_LTV100_1token_sTokens_fuzz(uint16 _collateral) public {
        _maxLiquidation_partial_LTV100_1token_fuzz(_collateral, _RECEIVE_STOKENS);
    }

    /*
    forge test -vv --ffi --mt test_maxLiquidation_partial_LTV100_1token_tokens_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 100
    function test_maxLiquidation_partial_LTV100_1token_tokens_fuzz(uint16 _collateral) public {
        _maxLiquidation_partial_LTV100_1token_fuzz(_collateral, !_RECEIVE_STOKENS);
    }

    function _maxLiquidation_partial_LTV100_1token_fuzz(uint16 _collateral, bool _receiveSToken) internal {
        // for small numbers we might jump from solvent -> 100% LTV, so partial liquidation not possible
        // I used `_findLTV100` to find range of numbers for which we jump to 100% for this casesetup

        // even if 100% is not bad debt, partial liquidation will be full liquidation
        // TODO for 100% we should not be able to liquiodate less??
        // TODO test cases solvent -> 100%
        // TODO test cases solvent -> dust (so full liquidation)
        vm.assume(_collateral < 20);
        bool _sameAsset = true;
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

        _executeLiquidation(_sameAsset, _receiveSToken);

        _assertBorrowerIsSolvent();
        _ensureBorrowerHasNoDebt();
    }

    /*
    forge test -vv --ffi --mt test_maxLiquidation_partial_LTV100_2tokens_sToken_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 100
    function test_maxLiquidation_partial_LTV100_2tokens_sToken_fuzz(uint16 _collateral) public {
        _maxLiquidation_partial_LTV100_2tokens_fuzz(_collateral, _RECEIVE_STOKENS);
    }

    /*
    forge test -vv --ffi --mt test_maxLiquidation_partial_LTV100_2tokens_token_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 100
    function test_maxLiquidation_partial_LTV100_2tokens_token_fuzz(uint16 _collateral) public {
        _maxLiquidation_partial_LTV100_2tokens_fuzz(_collateral, !_RECEIVE_STOKENS);
    }

    function _maxLiquidation_partial_LTV100_2tokens_fuzz(uint16 _collateral, bool _receiveSToken) internal {
        vm.assume(_collateral < 7);

        bool _sameAsset = false;
        uint256 toBorrow = uint256(_collateral) * 75 / 100; // maxLTV is 75%

        _createDebt(_collateral, toBorrow, _sameAsset);

        // this case never happen because is is not possible to create debt for 1 collateral
        if (_collateral == 1) _findLTV100();
        else if (_collateral == 2) vm.warp(3615 days);
        else if (_collateral == 3) vm.warp(66 days);
        else if (_collateral == 4) vm.warp(45 days);
        else if (_collateral == 5) vm.warp(95 days);
        else if (_collateral == 6) vm.warp(66 days);
        else revert("should not happen, because of vm.assume");

        _assertLTV100();

        _executeLiquidation(_sameAsset, _receiveSToken);

        _assertBorrowerIsSolvent();
        _ensureBorrowerHasNoDebt();
    }

    /*
    forge test -vv --ffi --mt test_maxLiquidation_partial_dust_1token_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 10000
//    function test_maxLiquidation_partial_dust_1token_fuzz(uint128 _collateral) public {
//        // TODO how to create cases for DUST?
//        // try to liquidate less
//
//        // this condition is to not have overflow: _collateral * 84
//        vm.assume(_collateral < type(uint128).max / 84);
//        // for small numbers we might jump from solvent -> bad debt, small numbers will be separate test casee TODO
//        // this value found by fuzzing tests, is high enough to have partial liquidation possible for this test setup
//        vm.assume(_collateral >= 20);
//
//        bool _sameAsset = true;
//        uint256 toBorrow = _collateral * 84 / 100; // maxLT is 85%
//
//        _createDebt(_collateral, toBorrow, _sameAsset);
//
//        // for same asset interest increasing slower, because borrower is also depositor, also LT is higher
//        // vm.warp(1260 days);
//
//        if (_collateral < 10) _moveTimeUntilInsolvent(); // vm.warp(3615 days);
//        // else if (_collateral < 100) _findWrapForSolvency();
//        else if (_collateral < 100) vm.warp(1455 days);
//        // else if (_collateral < 200) _findWrapForSolvency();
//        else if (_collateral < 200) vm.warp(1186 days);
//        else if (_collateral < 300) _moveTimeUntilInsolvent(); // vm.warp(3615 days);
//        else if (_collateral < 400) _moveTimeUntilInsolvent(); // vm.warp(3615 days);
//        else if (_collateral < 500) _moveTimeUntilInsolvent(); // vm.warp(3615 days);
//        else vm.warp(1260 days);
//
//        _assertBorrowerIsNotSolvent({_hasBadDebt: false});
//
////        _executeLiquidation(_sameAsset, false);
////
////        _assertBorrowerIsSolvent();
////        _ensureBorrowerHasDebt();
//    }

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

    /*
    forge test -vv --ffi --mt test_maxLiquidation_partial_1token_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 10000
    function _maxLiquidation_partial_1token_fuzz(uint128 _collateral, bool _receiveSToken) internal {
        // this condition is to not have overflow: _collateral * 84
        vm.assume(_collateral < type(uint128).max / 85);
        // for small numbers we might jump from solvent -> bad debt, small numbers will be separate test case TODO
        // this value found by fuzzing tests, is high enough to have partial liquidation possible for this test setup
        vm.assume(_collateral > 57); // 20..57 - dust cases

        bool _sameAsset = true;
        uint256 toBorrow = _collateral * 85 / 100; // maxLT is 85%

        _createDebt(_collateral, toBorrow, _sameAsset);

        // for same asset interest increasing slower, because borrower is also depositor, also LT is higher
        vm.warp(block.timestamp + 1050 days); // initial time movement to speed up _findWrapForSolvency
        _moveTimeUntilInsolvent();

        _assertBorrowerIsNotSolvent({_hasBadDebt: false}); // TODO make tests for bad debt as well

        _executeLiquidation(_sameAsset, _receiveSToken);

        _assertBorrowerIsSolvent();
        _ensureBorrowerHasDebt();
    }

    /*
    forge test -vv --ffi --mt test_maxLiquidation_partial_2tokens_sTokens_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxLiquidation_partial_2tokens_sTokens_fuzz(
    //    uint128 _collateral
    ) public {
        _maxLiquidation_partial_2tokens_fuzz(8, _RECEIVE_STOKENS);
    }

    /*
    forge test -vv --ffi --mt test_maxLiquidation_partial_2tokens_tokens_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxLiquidation_partial_2tokens_tokens_fuzz(uint128 _collateral) public {
        _maxLiquidation_partial_2tokens_fuzz(_collateral, !_RECEIVE_STOKENS);
    }

    function _maxLiquidation_partial_2tokens_fuzz(uint128 _collateral, bool _receiveSToken) internal {
        // this condition is to not have overflow: _collateral * 75
        vm.assume(_collateral < type(uint128).max / 75);
        // for small numbers we might jump from solvent -> bad debt, small numbers will be separate test case TODO
        vm.assume(_collateral >= 7);

        bool _sameAsset = false;
        uint256 toBorrow = _collateral * 75 / 100; // maxLT is 75%

        _createDebt(_collateral, toBorrow, _sameAsset);

        // for same asset interest increasing slower, because borrower is also depositor, also LT is higher
        vm.warp(block.timestamp + 20 days); // initial time movement to speed up _findWrapForSolvency
        _moveTimeUntilInsolvent();

        _assertBorrowerIsNotSolvent({_hasBadDebt: false});

        _executeLiquidation(_sameAsset, _receiveSToken);

        _assertBorrowerIsSolvent();
        _ensureBorrowerHasDebt();
    }
//
//    /*
//    forge test -vv --ffi --mt test_maxLiquidation_withInterest_fuzz
//    */
//    /// forge-config: core-test.fuzz.runs = 1000
//    function test_maxLiquidation_withInterest_1token_fuzz(uint128 _collateral) public {
//        _maxLiquidation_withInterest(_collateral, SAME_ASSET);
//    }
//
//    /// forge-config: core-test.fuzz.runs = 1000
//    function test_maxLiquidation_withInterest_2tokens_fuzz(uint128 _collateral) public {
//        _maxLiquidation_withInterest(_collateral, TWO_ASSETS);
//    }
//
//    function _maxLiquidation_withInterest(uint128 _collateral, bool _sameAsset) public {
//        uint256 toBorrow = _collateral / 3;
//        _createDebt(_collateral, toBorrow, _sameAsset);
//
//        vm.warp(block.timestamp + 356 days);
//
//        uint256 maxLiquidation = partialLiquidation.maxLiquidation(address(silo0), borrower);
//        vm.assume(maxLiquidation > toBorrow); // we want interest
//
//        _repay(maxLiquidation, borrower);
//        _assertBorrowerIsSolvent();
//    }

    function _createDebt(uint256 _collateral, uint256 _toBorrow, bool _sameAsset) internal {
        vm.assume(_collateral > 0);
        vm.assume(_toBorrow > 0);

        _depositForBorrow(_collateral, depositor);
        _depositCollateral(_collateral, borrower, _sameAsset);
        _borrow(_toBorrow, borrower, _sameAsset);

        _ensureBorrowerHasDebt();
    }

    function _ensureBorrowerHasDebt() internal view {
        (,, address debtShareToken) = silo1.config().getShareTokens(address(silo1));
        assertGt(IShareToken(debtShareToken).balanceOf(borrower), 0, "expect borrower with debt balance");
    }

    function _ensureBorrowerHasNoDebt() internal view {
        (,, address debtShareToken) = silo1.config().getShareTokens(address(silo1));
        assertEq(IShareToken(debtShareToken).balanceOf(borrower), 0, "expect borrower has NO debt balance");
    }

    function _assertBorrowerIsSolvent() internal view {
        assertTrue(silo1.isSolvent(borrower));

        (uint256 collateralToLiquidate, uint256 debtToRepay) = partialLiquidation.maxLiquidation(address(silo0), borrower);
        assertEq(collateralToLiquidate, 0);
        assertEq(debtToRepay, 0);

        (collateralToLiquidate, debtToRepay) = partialLiquidation.maxLiquidation(address(silo1), borrower);
        assertEq(collateralToLiquidate, 0);
        assertEq(debtToRepay, 0);
    }

    function _assertBorrowerIsNotSolvent(bool _hasBadDebt) internal {
        uint256 ltv = silo1.getLtv(borrower);
        emit log_named_decimal_uint("[_assertBorrowerIsNotSolvent] LTV", ltv, 16);

        assertFalse(silo1.isSolvent(borrower), "[_assertBorrowerIsNotSolvent] borrower is still solvent");

        if (_hasBadDebt) assertGt(ltv, 1e18, "[_assertBorrowerIsNotSolvent] LTV");
        else assertLe(ltv, 1e18, "[_assertBorrowerIsNotSolvent] LTV");
    }

    function _assertLTV100() internal {
        uint256 ltv = silo1.getLtv(borrower);
        emit log_named_decimal_uint("[_assertLTV100] LTV", ltv, 16);

        assertFalse(silo1.isSolvent(borrower), "[_assertLTV100] borrower is still solvent");

        assertEq(ltv, 1e18, "[_assertLTV100] LTV");
    }

    function _executeLiquidation(bool _sameToken, bool _receiveSToken) private {
        uint256 siloBalanceBefore0 = token0.balanceOf(address(silo0));
        uint256 siloBalanceBefore1 = token1.balanceOf(address(silo1));

        uint256 liquidatorBalanceBefore0 = token0.balanceOf(address(this));

        (
            uint256 collateralToLiquidate, uint256 debtToRepay
        ) = partialLiquidation.maxLiquidation(address(silo1), borrower);

        (uint256 withdrawCollateral, uint256 repayDebtAssets) = _executeMaxPartialLiquidation(_sameToken, _receiveSToken);

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
                assertEq(
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
                assertEq(
                    siloBalanceBefore0 - collateralToLiquidate,
                    token0.balanceOf(address(silo0)),
                    "collateral was moved from silo"
                );

                assertEq(
                    liquidatorBalanceBefore0 + collateralToLiquidate,
                    token0.balanceOf(address(this)),
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

    // TODO tests for _receiveSToken
    function _executeMaxPartialLiquidation(bool _sameToken, bool _receiveSToken)
        private
        returns (uint256 withdrawCollateral, uint256 repayDebtAssets)
    {
        // to test max, we want to provide higher `_debtToCover` and we expect not higher results
        uint256 debtToCover = type(uint256).max;

        (
            uint256 collateralToLiquidate, uint256 debtToRepay
        ) = partialLiquidation.maxLiquidation(address(silo1), borrower);

        (withdrawCollateral, repayDebtAssets) = partialLiquidation.liquidationCall(
            address(silo1),
            address(_sameToken ? token1 : token0),
            address(token1),
            borrower,
            debtToCover,
            _receiveSToken
        );

        assertEq(debtToRepay, repayDebtAssets, "debt: maxLiquidation == result");
        assertEq(collateralToLiquidate, withdrawCollateral, "collateral: max == result");
    }

    function _findLTV100() private {
        uint256 prevLTV = silo1.getLtv(borrower);

        for (uint256 i = 1; i < 10000; i++) {
            vm.warp(i * 60 * 60 * 24);
            uint256 ltv = silo1.getLtv(borrower);

            emit log_named_decimal_uint("[_assertLTV100] LTV", ltv, 16);
            emit log_named_uint("[_assertLTV100] days", i);

            if (ltv == 1e18) revert("found");

            if (ltv != prevLTV && !silo1.isSolvent(borrower)) {
                emit log_named_decimal_uint("[_assertLTV100] prevLTV was", prevLTV, 16);
                revert("we found middle step between solvent and 100%");
            } else {
                prevLTV = silo1.getLtv(borrower);
            }
        }
    }

    function _moveTimeUntilInsolvent() private {
        for (uint256 i = 1; i < 10000; i++) {
             // emit log_named_decimal_uint("[_assertLTV100] LTV", silo1.getLtv(borrower), 16);
             // emit log_named_uint("[_assertLTV100] days", i);

            if (!silo1.isSolvent(borrower)) {
                emit log_named_decimal_uint("[_findWrapForSolvency] LTV", silo1.getLtv(borrower), 16);
                emit log_named_uint("[_findWrapForSolvency] days", i);

                return;
            }

            vm.warp(block.timestamp + i * 60 * 60 * 24);
        }
    }

}
