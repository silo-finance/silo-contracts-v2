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
contract MaxRepayTest is SiloLittleHelper, Test {
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
    forge test -vv --ffi --mt test_maxRepay_noDebt
    */
    function test_maxRepay_noDebt() public {
        uint256 maxRepay = silo1.maxRepay(borrower);
        assertEq(maxRepay, 0, "no debt - nothing to repay");

        _depositForBorrow(11e18, borrower);

        _assertBorrowerHasNoDebt();
    }

    /*
    forge test -vv --ffi --mt test_maxRepay_withDebt_
    */
    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxRepay_withDebt_1token_fuzz(uint128 _collateral) public {
        _maxRepay_withDebt(_collateral, SAME_ASSET);
    }

    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxRepay_withDebt_2tokens_fuzz(uint128 _collateral) public {
        _maxRepay_withDebt(_collateral, TWO_ASSETS);
    }

    function _maxRepay_withDebt(uint128 _collateral, bool _sameAsset) private {
        uint256 toBorrow = _collateral / 3;
        _createDebt(_collateral, toBorrow, _sameAsset);

        uint256 maxRepay = silo1.maxRepay(borrower);
        assertEq(maxRepay, toBorrow, "max repay is what was borrower if no interest");

        _repay(maxRepay, borrower);
        _assertBorrowerHasNoDebt();
    }

    /*
    forge test -vv --ffi --mt test_maxRepay_withInterest_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxRepay_withInterest_1token_fuzz(uint128 _collateral) public {
        _maxRepay_withInterest(_collateral, SAME_ASSET);
    }

    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxRepay_withInterest_2tokens_fuzz(uint128 _collateral) public {
        _maxRepay_withInterest(_collateral, TWO_ASSETS);
    }

    function _maxRepay_withInterest(uint128 _collateral, bool _sameAsset) public {
        uint256 toBorrow = _collateral / 3;
        _createDebt(_collateral, toBorrow, _sameAsset);

        vm.warp(block.timestamp + 356 days);

        uint256 maxRepay = silo1.maxRepay(borrower);
        vm.assume(maxRepay > toBorrow); // we want interest

        _repay(maxRepay, borrower);
        _assertBorrowerHasNoDebt();
    }

    function _createDebt(uint256 _collateral, uint256 _toBorrow, bool _sameAsset) internal {
        vm.assume(_collateral > 0);
        vm.assume(_toBorrow > 0);

        _depositForBorrow(_collateral, depositor);
        _depositCollateral(_collateral, borrower, _sameAsset);
        _borrow(_toBorrow, borrower, _sameAsset);

        _ensureBorrowerHasDebt();
    }

    function _ensureBorrowerHasDebt() internal {
        (,, address debtShareToken) = silo1.config().getShareTokens(address(silo1));

        assertGt(silo1.maxRepay(borrower), 0, "expect debt");
        assertGt(IShareToken(debtShareToken).balanceOf(borrower), 0, "expect debtShareToken balance > 0");
    }

    function _assertBorrowerHasNoDebt() internal {
        (,, address debtShareToken) = silo1.config().getShareTokens(address(silo1));

        assertEq(silo1.maxRepay(borrower), 0, "expect maxRepay to be 0");
        assertEq(IShareToken(debtShareToken).balanceOf(borrower), 0, "expect debtShareToken balance to be 0");
    }
}
