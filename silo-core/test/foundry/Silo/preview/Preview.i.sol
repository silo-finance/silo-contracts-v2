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
    forge test -vv --ffi --mc PreviewTest
*/
contract PreviewTest is SiloLittleHelper, Test {
    uint256 constant DEPOSIT_BEFORE = 1e18 + 9876543211;

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
    forge test -vv --ffi --mt test_previewBorrow_zero_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 10000
    function test_previewBorrow_zero_fuzz(uint256 _assets, bool _useShares) public {
        assertEq(_useShares ? silo0.previewBorrowShares(_assets) : silo0.previewBorrow(_assets), _assets);
    }

    /*
    forge test -vv --ffi --mt test_previewBorrow_beforeInterest_
    */
    /// forge-config: core-test.fuzz.runs = 10000
    function test_previewBorrow_beforeInterest_1token_fuzz(uint128 _assets, bool _useShares) public {
        _previewBorrow_beforeInterest(_assets, _useShares, SAME_ASSET);
    }

    /// forge-config: core-test.fuzz.runs = 10000
    function test_previewBorrow_beforeInterest_2tokens_fuzz(uint128 _assets, bool _useShares) public {
        _previewBorrow_beforeInterest(_assets, _useShares, TWO_ASSETS);
    }

    function _previewBorrow_beforeInterest(uint128 _assets, bool _useShares, bool _sameAsset) private {
        uint256 assetsOrSharesToBorrow = _assets / 10 + (_assets % 2); // keep even/odd
        vm.assume(assetsOrSharesToBorrow < _assets);

        // can be 0 if _assets < 10
        if (assetsOrSharesToBorrow == 0) {
            _assets = 3;
            assetsOrSharesToBorrow = 1;
        }

        _createBorrowCase(_assets, _sameAsset);

        uint256 preview = _useShares
            ? silo1.previewBorrowShares(assetsOrSharesToBorrow)
            : silo1.previewBorrow(assetsOrSharesToBorrow);

        uint256 result = _useShares
            ? _borrow(assetsOrSharesToBorrow, borrower, _sameAsset)
            : _borrowShares(assetsOrSharesToBorrow, borrower, _sameAsset);

        assertEq(preview, assetsOrSharesToBorrow, "previewBorrow shares are exact as amount when no interest");
        assertEq(preview, result, "previewBorrow - expect exact match");
    }

    /*
    forge test -vv --ffi --mt test_previewBorrow_withInterest
    */
    /// forge-config: core-test.fuzz.runs = 10000
    function test_previewBorrow_withInterest_1token_fuzz(uint128 _assets, bool _useShares) public {
        _previewBorrow_withInterest(_assets, _useShares, SAME_ASSET);
    }

    /// forge-config: core-test.fuzz.runs = 10000
    function test_previewBorrow_withInterest_2tokens_fuzz(uint128 _assets, bool _useShares) public {
        _previewBorrow_withInterest(_assets, _useShares, TWO_ASSETS);
    }

    function _previewBorrow_withInterest(uint128 _assets, bool _useShares, bool _sameAsset) private {
        uint256 assetsOrSharesToBorrow = _assets / 10 + (_assets % 2); // keep even/odd
        vm.assume(assetsOrSharesToBorrow < _assets);

        if (assetsOrSharesToBorrow == 0) {
            _assets = 3;
            assetsOrSharesToBorrow = 1;
        }

        _createBorrowCase(_assets, _sameAsset);

        vm.warp(block.timestamp + 365 days);

        uint256 preview = _useShares
            ? silo1.previewBorrowShares(assetsOrSharesToBorrow)
            : silo1.previewBorrow(assetsOrSharesToBorrow);
        uint256 result = _useShares
            ? _borrowShares(assetsOrSharesToBorrow, borrower, _sameAsset)
            : _borrow(assetsOrSharesToBorrow, borrower, _sameAsset);

        assertEq(
            preview,
            result,
            string.concat(_useShares ? "[shares]" : "[assets]", " previewBorrow - expect exact match")
        );
    }

    /*
    forge test -vv --ffi --mt test_previewRepay_noInterestNoDebt_
    */
    /// forge-config: core-test.fuzz.runs = 10000
    function test_previewRepay_noInterestNoDebt_1token_fuzz(uint128 _assetsOrShares, bool _useShares, bool _repayFull)
        public
    {
        _previewRepay_noInterestNoDebt(_assetsOrShares, _useShares, _repayFull, SAME_ASSET);
    }

    /// forge-config: core-test.fuzz.runs = 10000
    function test_previewRepay_noInterestNoDebt_2tokens_fuzz(uint128 _assetsOrShares, bool _useShares, bool _repayFull)
        public
    {
        _previewRepay_noInterestNoDebt(_assetsOrShares, _useShares, _repayFull, TWO_ASSETS);
    }

    function _previewRepay_noInterestNoDebt(
        uint128 _assetsOrShares,
        bool _useShares,
        bool _repayFull,
        bool _sameAsset
    ) private {
        uint128 amountToUse = _repayFull ? _assetsOrShares : uint128(uint256(_assetsOrShares) * 37 / 100);
        vm.assume(amountToUse > 0);

        // preview before debt creation
        uint256 preview = _useShares ? silo1.previewRepayShares(amountToUse) : silo1.previewRepay(amountToUse);

        _createDebt(_assetsOrShares, borrower, _sameAsset);

        assertEq(preview, amountToUse, "previewRepay == assets == shares, when no interest");

        _assertPreviewRepay(preview, amountToUse, _useShares);
    }

    /*
    forge test -vv --ffi --mt test_previewRepayShares_noInterest_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 10000
    function test_previewRepay_noInterest_1token_fuzz(uint128 _assetsOrShares, bool _useShares, bool _repayFull) public {
        _previewRepay_noInterest(_assetsOrShares, _useShares, _repayFull, SAME_ASSET);
    }

    /// forge-config: core-test.fuzz.runs = 10000
    function test_previewRepay_noInterest_2tokens_fuzz(uint128 _assetsOrShares, bool _useShares, bool _repayFull) public {
        _previewRepay_noInterest(_assetsOrShares, _useShares, _repayFull, TWO_ASSETS);
    }

    function _previewRepay_noInterest(uint128 _assetsOrShares, bool _useShares, bool _repayFull, bool _sameAsset) private {
        uint128 amountToUse = _repayFull ? _assetsOrShares : uint128(uint256(_assetsOrShares) * 37 / 100);
        vm.assume(amountToUse > 0);

        _createDebt(_assetsOrShares, borrower, _sameAsset);

        uint256 preview = _useShares ? silo1.previewRepayShares(amountToUse) : silo1.previewRepay(amountToUse);

        assertEq(preview, amountToUse, "previewRepay == assets == shares, when no interest");

        _assertPreviewRepay(preview, amountToUse, _useShares);
    }

    /*
    forge test -vv --ffi --mt test_previewRepay_withInterest_
    */
    /// forge-config: core-test.fuzz.runs = 10000
    function test_previewRepay_withInterest_1token_fuzz(
        // uint128 _assetsOrShares, bool _useShares, bool _repayFull
    )
        public
    {
        (uint128 _assetsOrShares, bool _useShares, bool _repayFull) = (280, true, true);
        _previewRepay_withInterest(_assetsOrShares, _useShares, _repayFull, SAME_ASSET);
    }

    /// forge-config: core-test.fuzz.runs = 10000
    function test_previewRepay_withInterest_2tokens_fuzz(uint128 _assetsOrShares, bool _useShares, bool _repayFull)
        public
    {
        _previewRepay_withInterest(_assetsOrShares, _useShares, _repayFull, TWO_ASSETS);
    }

    function _previewRepay_withInterest(
        uint128 _assetsOrShares,
        bool _useShares,
        bool _repayFull,
        bool _sameAsset
    ) private {
        uint128 amountToUse = _repayFull ? _assetsOrShares : uint128(uint256(_assetsOrShares) * 37 / 100);
        vm.assume(amountToUse > 0);

        _createDebt(_assetsOrShares, borrower, _sameAsset);
        vm.warp(block.timestamp + 100 days);

        uint256 preview = _useShares ? silo1.previewRepayShares(amountToUse) : silo1.previewRepay(amountToUse);

        _assertPreviewRepay(preview, amountToUse, _useShares);
    }

    function _assertPreviewRepay(uint256 _preview, uint128 _assetsOrShares, bool _useShares) internal {
        vm.assume(_preview > 0);

        uint256 repayResult = _useShares
            ? _repayShares(type(uint256).max, _assetsOrShares, borrower)
            : _repay(_assetsOrShares, borrower);

        assertGt(repayResult, 0, "expect any repay amount > 0");

        assertEq(
            _preview,
            repayResult,
            string.concat(_useShares ? "[shares]" : "[amount]", " preview should give us exact repay result")
        );
    }

    function _createBorrowCase(uint128 _assets, bool _sameAsset) internal {
        address somebody = makeAddr("Somebody");

        _depositCollateral(_assets, borrower, _sameAsset);

        // deposit to both silos
        _deposit(_assets, somebody);
        _depositForBorrow(_assets, somebody);
    }
}