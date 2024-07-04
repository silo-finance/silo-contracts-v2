// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

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
    uint256 internal constant _REAL_ASSETS_LIMIT = type(uint128).max;
    
    ISiloConfig siloConfig;
    address immutable depositor;
    address immutable borrower;

    constructor() {
        depositor = makeAddr("Depositor");
        borrower = makeAddr("Borrower");
    }

    function setUp() public {
        siloConfig = _setUpLocalFixture(SiloConfigsNames.LOCAL_NO_ORACLE_NO_LTV_SILO);
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
    forge test -vv --ffi --mt test_maxLiquidation_withDebt_
    */
    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxLiquidation_partial_1token_fuzz(uint128 _collateral) public {
        _maxLiquidation_withDebt(_collateral, SAME_ASSET);
    }

    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxLiquidation_partial_2tokens_fuzz(uint128 _collateral) public {
        _maxLiquidation_withDebt(_collateral, TWO_ASSETS);
    }

    function _maxLiquidation_partial(uint128 _collateral, bool _sameAsset) private {
        uint256 toBorrow = _collateral / 3;
        _createDebt(_collateral, toBorrow, _sameAsset);

        vm.warp(1000);

        _assertBorrowerIsNotSolvent(false);

        (uint256 collateralToLiquidate, uint256 debtToRepay) = partialLiquidation.maxLiquidation(address(silo0), borrower);
        assertGt(debtToRepay, toBorrow, "debtToRepay is more with interest than what was borrowed");
        assertEq(collateralToLiquidate, _collateral, "_collateral is exact");

        (uint256 withdrawCollateral, uint256 repayDebtAssets) = _executeLiquidation(_sameAsset, debtToRepay, false);

        assertEq(debtToRepay, repayDebtAssets, "debt: max == result");
        assertEq(collateralToLiquidate, withdrawCollateral, "collateral: max == result");

        _assertBorrowerIsSolvent();
    }

    /*
    forge test -vv --ffi --mt test_maxLiquidation_withInterest_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxLiquidation_withInterest_1token_fuzz(uint128 _collateral) public {
        _maxLiquidation_withInterest(_collateral, SAME_ASSET);
    }

    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxLiquidation_withInterest_2tokens_fuzz(uint128 _collateral) public {
        _maxLiquidation_withInterest(_collateral, TWO_ASSETS);
    }

    function _maxLiquidation_withInterest(uint128 _collateral, bool _sameAsset) public {
        uint256 toBorrow = _collateral / 3;
        _createDebt(_collateral, toBorrow, _sameAsset);

        vm.warp(block.timestamp + 356 days);

        uint256 maxLiquidation = partialLiquidation.maxLiquidation(address(silo0), borrower);
        vm.assume(maxLiquidation > toBorrow); // we want interest

        _repay(maxLiquidation, borrower);
        _assertBorrowerIsSolvent();
    }

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

        assertGt(partialLiquidation.maxLiquidation(address(silo0), borrower), 0, "expect debt");
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

    function _assertBorrowerIsNotSolvent(bool _hasBadDebt) internal view {
        assertFalse(silo1.isSolvent(borrower));

        if (_hasBadDebt) assertGt(silo1.getLtv(borrower), 1e18);
        else assertLt(silo1.getLtv(borrower), 1e18);
    }

    function _executeLiquidation(bool _sameToken, uint256 _debtToCover, bool _receiveSToken)
        private
        returns (uint256 withdrawCollateral, uint256 repayDebtAssets)
    {
        token0.mint(address(this), _debtToCover);
        token0.approve(address(partialLiquidation), _debtToCover);

        return partialLiquidation.liquidationCall(
            address(_sameToken ? silo0 : silo1),
            address(token0),
            address(_sameToken ? token0 : token1),
            borrower,
            _debtToCover,
            _receiveSToken
        );
    }
}
