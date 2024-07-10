// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IPartialLiquidation} from "silo-core/contracts/interfaces/IPartialLiquidation.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";

import {MintableToken} from "../../_common/MintableToken.sol";
import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc MaxLiquidationDustTest
*/
contract MaxLiquidationDustTest is SiloLittleHelper, Test {
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
    forge test -vv --ffi --mt test_maxLiquidation_dust_LTV100_2tokens_sToken
    */
    /// forge-config: core-test.fuzz.runs = 100
    function test_maxLiquidation_dust_LTV100_2tokens_sToken() public {
        _maxLiquidation_partial_LTV100_2tokens(12, _RECEIVE_STOKENS);
    }

    /*
    forge test -vv --ffi --mt test_maxLiquidation_dust_LTV100_2tokens_token_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 100
    function test_maxLiquidation_dust_LTV100_2tokens_token_fuzz(uint16 _collateral) public {
        _maxLiquidation_partial_LTV100_2tokens(_collateral, !_RECEIVE_STOKENS);
    }

    function _maxLiquidation_partial_LTV100_2tokens(uint16 _collateral, bool _receiveSToken) internal {
        bool _sameAsset = false;

        uint256 toBorrow = uint256(_collateral) * 75 / 100; // maxLTV is 75%

        _createDebt(_collateral, toBorrow, _sameAsset);

        // this case never happen because is is not possible to create debt for 1 collateral
        if (_collateral == 12) _findLTV100(); // vm.warp(10 days);
        else revert("should not happen, because of vm.assume");

        _assertLTV100();

        _executeDustLiquidation(_sameAsset, _receiveSToken);

        _assertBorrowerIsSolvent();
        _ensureBorrowerHasNoDebt();
    }

    /*
    forge test -vv --ffi --mt test_maxLiquidation_dust_dust_1token_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 100
    function test_maxLiquidation_dust_dust_1token_fuzz(
        uint128 _collateral
    ) public {
//        uint128 _collateral = 56;

        bool _sameAsset = true;

        // TODO how to create cases for DUST?
        // try to liquidate less

        // this condition is to not have overflow: _collateral * 84
        vm.assume(_collateral < type(uint128).max / 84);

        uint256 toBorrow = _collateral * 84 / 100; // maxLT is 85%

        _createDebt(_collateral, toBorrow, _sameAsset);

        // for same asset interest increasing slower, because borrower is also depositor, also LT is higher
        // vm.warp(1260 days);

        if (_collateral == 1) _findLTV100();
//         else if (_collateral == 12) _findLTV100();
        else if (_collateral == 12) vm.warp(1141 days);
//         else if (_collateral >= 20 && _collateral < 57) _findLTV100();
        else if (_collateral >= 20 && _collateral < 57) vm.warp(1300 days);
        else vm.assume(false);

        _moveTimeUntilInsolvent();

        _assertBorrowerIsNotSolvent({_hasBadDebt: false}); // TODO make tests for bad debt as well

        bool _receiveSToken = true;
        _executeDustLiquidation(_sameAsset, _receiveSToken);

        _assertBorrowerIsSolvent();
        _ensureBorrowerHasNoDebt();
    }

    /*
    forge test -vv --ffi --mt test_maxLiquidation_dust_1token_sTokens_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 10000
    function test_maxLiquidation_dust_1token_sTokens_fuzz(uint128 _collateral) public {
        _maxLiquidation_partial_1token_fuzz(_collateral, _RECEIVE_STOKENS);
    }

    /*
    forge test -vv --ffi --mt test_maxLiquidation_dust_1token_tokens_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 10000
    function test_maxLiquidation_dust_1token_tokens_fuzz(uint128 _collateral) public {
        _maxLiquidation_partial_1token_fuzz(_collateral, !_RECEIVE_STOKENS);
    }

    function _maxLiquidation_partial_1token_fuzz(uint128 _collateral, bool _receiveSToken) internal {
        bool _sameAsset = true;

        // this condition is to not have overflow: _collateral * 85
        vm.assume(_collateral < type(uint128).max / 85);
         // this value found by fuzzing tests, is high enough to have partial liquidation possible for this test setup
        vm.assume(_collateral >= 57); // 20..57 - dust cases TODO

        uint256 toBorrow = _collateral * 85 / 100; // maxLT is 85%

        _createDebt(_collateral, toBorrow, _sameAsset);

        vm.warp(block.timestamp + 1050 days); // initial time movement to speed up _moveTimeUntilInsolvent
        _moveTimeUntilInsolvent();

        _assertBorrowerIsNotSolvent({_hasBadDebt: false}); // TODO make tests for bad debt as well

        _executeDustLiquidation(_sameAsset, _receiveSToken);

        _assertBorrowerIsSolvent();
        _ensureBorrowerHasDebt();
    }

    /*
    forge test -vv --ffi --mt test_maxLiquidation_dust_2tokens_sTokens_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxLiquidation_dust_2tokens_sTokens_fuzz(uint128 _collateral) public {
        _maxLiquidation_partial_2tokens_fuzz(_collateral, _RECEIVE_STOKENS);
    }

    /*
    forge test -vv --ffi --mt test_maxLiquidation_dust_2tokens_tokens_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxLiquidation_dust_2tokens_tokens_fuzz(uint128 _collateral) public {
        _maxLiquidation_partial_2tokens_fuzz(_collateral, !_RECEIVE_STOKENS);
    }

    function _maxLiquidation_partial_2tokens_fuzz(uint128 _collateral, bool _receiveSToken) internal {
        bool _sameAsset = false;

        vm.assume(_collateral != 12); // 100 LTV case
        vm.assume(_collateral != 19); // dust case

        // this condition is to not have overflow: _collateral * 75
        vm.assume(_collateral < type(uint128).max / 75);
        vm.assume(_collateral >= 7); // only partial liquidation

        uint256 toBorrow = _collateral * 75 / 100; // maxLT is 75%

        _createDebt(_collateral, toBorrow, _sameAsset);

        // for same asset interest increasing slower, because borrower is also depositor, also LT is higher
        _moveTimeUntilInsolvent();

        _assertBorrowerIsNotSolvent({_hasBadDebt: false});

        _executeDustLiquidation(_sameAsset, _receiveSToken);

        _assertBorrowerIsSolvent();
        _ensureBorrowerHasDebt();
    }
//
//    /*
//    forge test -vv --ffi --mt test_maxLiquidation_dust_withInterest_fuzz
//    */
//    /// forge-config: core-test.fuzz.runs = 1000
//    function test_maxLiquidation_dust_withInterest_1token_fuzz(uint128 _collateral) public {
//        _maxLiquidation_withInterest(_collateral, SAME_ASSET);
//    }
//
//    /// forge-config: core-test.fuzz.runs = 1000
//    function test_maxLiquidation_dust_withInterest_2tokens_fuzz(uint128 _collateral) public {
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
        assertGt(silo0.getLtv(borrower), 0, "expect borrower has some LTV");
    }

    function _ensureBorrowerHasNoDebt() internal view {
        (,, address debtShareToken) = silo1.config().getShareTokens(address(silo1));
        assertEq(IShareToken(debtShareToken).balanceOf(borrower), 0, "expect borrower has NO debt balance");
        assertEq(silo0.getLtv(borrower), 0, "expect borrower has NO LTV");
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

    function _executeDustLiquidation(bool _sameToken, bool _receiveSToken) private {
        uint256 siloBalanceBefore0 = token0.balanceOf(address(silo0));
        uint256 siloBalanceBefore1 = token1.balanceOf(address(silo1));

        uint256 liquidatorBalanceBefore0 = token0.balanceOf(address(this));

        (
            uint256 collateralToLiquidate, uint256 debtToRepay
        ) = partialLiquidation.maxLiquidation(address(silo1), borrower);

        (uint256 withdrawCollateral, uint256 repayDebtAssets) = _executeMaxPartialDustLiquidation(_sameToken, _receiveSToken);

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

    function _executeMaxPartialDustLiquidation(bool _sameToken, bool _receiveSToken)
        private
        returns (uint256 withdrawCollateral, uint256 repayDebtAssets)
    {
        (
            uint256 collateralToLiquidate, uint256 debtToRepay
        ) = partialLiquidation.maxLiquidation(address(silo1), borrower);

        emit log_named_decimal_uint("[_executeMaxPartialDustLiquidation] ltv before", silo0.getLtv(borrower), 16);

        // with dust there should be not possible to liquidate with any other amount than full.
        _expectRevertWithDebtToCoverTooSmall(_sameToken, _receiveSToken, debtToRepay / 2);
        _expectRevertWithDebtToCoverTooSmall(_sameToken, _receiveSToken, debtToRepay - 1);
        _expectRevertWithDebtToCoverTooSmall(_sameToken, _receiveSToken, 1);

        // to test max, we want to provide higher `_debtToCover` and we expect not higher results
        // also to make sure we can execute with exact `debtToRepay` we will pick exact amount conditionally
        uint256 debtToCover = debtToRepay % 2 == 0 ? type(uint256).max : debtToRepay;

        (withdrawCollateral, repayDebtAssets) = partialLiquidation.liquidationCall(
            address(silo1),
            address(_sameToken ? token1 : token0),
            address(token1),
            borrower,
            debtToCover,
            _receiveSToken
        );

        assertEq(silo0.getLtv(borrower), 0, "[_executeMaxPartialDustLiquidation] expect full liquidation with dust");
        assertEq(debtToRepay, repayDebtAssets, "[_executeMaxPartialDustLiquidation] debt: maxLiquidation == result");

        assertEq(
            collateralToLiquidate,
            withdrawCollateral,
            "[_executeMaxPartialDustLiquidation] collateral: max == result"
        );
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
              emit log_named_decimal_uint("[_assertLTV100] LTV", silo1.getLtv(borrower), 16);
              emit log_named_uint("[_assertLTV100] days", i);

            bool isSolvent = silo1.isSolvent(borrower);

            if (!isSolvent) {
                emit log_named_string("[_findWrapForSolvency] user solwent?", isSolvent ? "yes" : "NO");
                emit log_named_decimal_uint("[_findWrapForSolvency] LTV", silo1.getLtv(borrower), 16);
                emit log_named_uint("[_findWrapForSolvency] days", i);

                return;
            }

            vm.warp(block.timestamp + i * 60 * 60 * 24);
        }
    }

    function _expectRevertWithDebtToCoverTooSmall(bool _sameToken, bool _receiveSToken, uint256 _debtToCover) private {
        vm.expectRevert(IPartialLiquidation.DebtToCoverTooSmall.selector);

        partialLiquidation.liquidationCall(
            address(silo1),
            address(_sameToken ? token1 : token0),
            address(token1),
            borrower,
            _debtToCover,
            _receiveSToken
        );
    }
}
