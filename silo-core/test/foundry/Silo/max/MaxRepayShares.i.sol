// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";

import {MintableToken} from "../../_common/MintableToken.sol";
import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc MaxRepaySharesTest
*/
contract MaxRepaySharesTest is SiloLittleHelper, Test {
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
    forge test -vv --ffi --mt test_maxRepayShares_noDebt
    */
    function test_maxRepayShares_noDebt() public {
        uint256 maxRepayShares = silo1.maxRepayShares(borrower);
        assertEq(maxRepayShares, 0, "no debt - nothing to repay");

        _depositForBorrow(11e18, borrower);

        _assertBorrowerHasNoDebt();
    }

    /*
    forge test -vv --ffi --mt test_maxRepayShares_withDebt_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxRepayShares_withDebt_1token_fuzz(uint128 _collateral) public {
        _maxRepayShares_withDebt(_collateral, true);
    }

    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxRepayShares_withDebt_2tokens_fuzz(uint128 _collateral) public {
        _maxRepayShares_withDebt(_collateral, false);
    }

    function _maxRepayShares_withDebt(uint128 _collateral, bool _sameToken) private {
        uint256 toBorrow = _collateral / 3;
        _createDebt(_collateral, toBorrow, _sameToken);

        uint256 maxRepayShares = silo1.maxRepayShares(borrower);
        assertEq(maxRepayShares, toBorrow, "max repay is what was borrower if no interest");

        _repayShares(maxRepayShares, maxRepayShares, borrower);
        _assertBorrowerHasNoDebt();
    }

    /*
    forge test -vv --ffi --mt test_maxRepayShares_withInterest_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxRepayShares_withInterest_1token_fuzz(uint128 _collateral) public {
        _maxRepayShares_withInterest(_collateral, true);
    }

    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxRepayShares_withInterest_2tokens_fuzz(uint128 _collateral) public {
        _maxRepayShares_withInterest(_collateral, false);
    }

    function _maxRepayShares_withInterest(uint128 _collateral, bool _sameToken) private {
        uint256 toBorrow = _collateral / 3;
        uint256 shares = _createDebt(_collateral, toBorrow, _sameToken);

        vm.warp(block.timestamp + 356 days);

        uint256 maxRepayShares = silo1.maxRepayShares(borrower);
        assertEq(maxRepayShares, shares, "shares are always the same");

        token1.setOnDemand(true);
        _repayShares(1, maxRepayShares, borrower);
        _assertBorrowerHasNoDebt();
    }

    function _createDebt(uint256 _collateral, uint256 _toBorrow, bool _sameToken) internal returns (uint256 shares) {
        vm.assume(_collateral > 0);
        vm.assume(_toBorrow > 0);

        _depositForBorrow(_collateral, depositor);
        _depositCollateral(_collateral, borrower, _sameToken);

        shares = _borrow(_toBorrow, borrower, _sameToken);

        _ensureBorrowerHasDebt();
    }

    function _ensureBorrowerHasDebt() internal {
        (,, address debtShareToken) = silo1.config().getShareTokens(address(silo1));

        assertGt(silo1.maxRepayShares(borrower), 0, "expect debt");
        assertGt(IShareToken(debtShareToken).balanceOf(borrower), 0, "expect debtShareToken balance > 0");
    }

    function _assertBorrowerHasNoDebt() internal {
        (,, address debtShareToken) = silo1.config().getShareTokens(address(silo1));

        assertEq(silo1.maxRepayShares(borrower), 0, "expect maxRepayShares to be 0");
        assertEq(IShareToken(debtShareToken).balanceOf(borrower), 0, "expect debtShareToken balanace to be 0");
    }
}
