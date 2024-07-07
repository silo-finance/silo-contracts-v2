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
    uint256 internal constant _REAL_ASSETS_LIMIT = type(uint128).max;
    
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
    forge test -vv --ffi --mt test_maxLiquidation_partial_1token_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxLiquidation_partial_1token_fuzz(uint128 _collateral) public {
        // this condition is to not have overflow: _collateral * 84
        vm.assume(_collateral < type(uint128).max / 84);
        // for small numbers we might jump from solvent -> bad debt, small numbers will be separate test casee TODO
        vm.assume(_collateral >= 1000);

        bool _sameAsset = true;

        uint256 toBorrow = _collateral * 84 / 100;
        _createDebt(_collateral, toBorrow, _sameAsset);

        // for same asset interest increasing slower, because borrower is also depositor, also LT is higher
        vm.warp(1260 days);

        _assertBorrowerIsNotSolvent({_hasBadDebt: false});

        (uint256 collateralToLiquidate, uint256 debtToRepay) = partialLiquidation.maxLiquidation(address(silo1), borrower);
        assertGt(debtToRepay, toBorrow, "debtToRepay is more with interest than what was borrowed");
        assertLt(collateralToLiquidate, _collateral, "expect part of _collateral on liquidation");

        (uint256 withdrawCollateral, uint256 repayDebtAssets) = _executeMaxLiquidation(_sameAsset, false);

        assertEq(debtToRepay, repayDebtAssets, "debt: we expect to not be able to repay more than max");
        assertEq(collateralToLiquidate, withdrawCollateral, "collateral: we can not get more than max");

        _assertBorrowerIsSolvent();
    }

    /*
    forge test -vv --ffi --mt test_maxLiquidation_partial_2tokens_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxLiquidation_partial_2tokens_fuzz(uint128 _collateral) public {
        // this condition is to not have overflow: _collateral * 74
        vm.assume(_collateral < type(uint128).max / 74);
        // for small numbers we might jump from solvent -> bad debt, small numbers will be separate test case TODO
        vm.assume(_collateral >= 1000);

        bool _sameAsset = false;

        uint256 toBorrow = _collateral * 74 / 100;
        _createDebt(_collateral, toBorrow, _sameAsset);

        vm.warp(40 days);

        _assertBorrowerIsNotSolvent(false);

        (uint256 collateralToLiquidate, uint256 debtToRepay) = partialLiquidation.maxLiquidation(address(silo1), borrower);
        assertGt(debtToRepay, toBorrow, "debtToRepay is more with interest than what was borrowed");
        assertLt(collateralToLiquidate, _collateral, "expect part of _collateral on liquidation");

        (uint256 withdrawCollateral, uint256 repayDebtAssets) = _executeMaxLiquidation(_sameAsset, false);

        assertEq(debtToRepay, repayDebtAssets, "debt: max == result");
        assertEq(collateralToLiquidate, withdrawCollateral, "collateral: max == result");

        _assertBorrowerIsSolvent();
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
        assertGt(IShareToken(debtShareToken).balanceOf(borrower), 0, "expect debtShareToken balance > 0");
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
        else assertLt(ltv, 1e18, "[_assertBorrowerIsNotSolvent] LTV");
    }

    function _executeMaxLiquidation(bool _sameToken, bool _receiveSToken)
        private
        returns (uint256 withdrawCollateral, uint256 repayDebtAssets)
    {
        uint256 debtToCover = type(uint256).max;
        token1.approve(address(partialLiquidation), debtToCover);

        // to test max, we want to provide higher `_debtToCover` and we expect not higher results

        return partialLiquidation.liquidationCall(
            address(silo1),
            address(_sameToken ? token1 : token0),
            address(token1),
            borrower,
            debtToCover,
            _receiveSToken
        );
    }
}
