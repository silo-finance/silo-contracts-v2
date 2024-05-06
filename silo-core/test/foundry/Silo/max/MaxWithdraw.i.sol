// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";
import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";

import {MaxWithdrawCommon} from "./MaxWithdrawCommon.sol";

/*
    forge test -vv --ffi --mc MaxWithdrawTest
*/
contract MaxWithdrawTest is MaxWithdrawCommon {
    using SiloLensLib for ISilo;

    function setUp() public {
        _setUpLocalFixture(SiloConfigsNames.LOCAL_NO_ORACLE_NO_LTV_SILO);
    }

    /*
    forge test -vv --ffi --mt test_maxWithdraw_zero
    */
    function test_maxWithdraw_zero() public {
        uint256 maxWithdraw = silo1.maxWithdraw(borrower);
        assertEq(maxWithdraw, 0, "nothing to withdraw");
    }

    /*
    forge test -vv --ffi --mt test_maxWithdraw_deposit_
    */
    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxWithdraw_deposit_fuzz(
        uint112 _assets,
        uint16 _assets2
    ) public {
        vm.assume(_assets > 0);
        vm.assume(_assets2 > 0);

        _deposit(_assets, borrower);
        _deposit(_assets2, address(1)); // any

        uint256 maxWithdraw = silo0.maxWithdraw(borrower);
        assertEq(maxWithdraw, _assets, "max withdraw == _assets if no interest");

        _assertBorrowerCanNotWithdrawMore(maxWithdraw, TWO_ASSETS);
        _assertMaxWithdrawIsZeroAtTheEnd(TWO_ASSETS);
    }

    /*
    forge test -vv --ffi --mt test_maxWithdraw_withDebt_
    */
    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxWithdraw_withDebt_1token_fuzz(
        uint128 _collateral,
        uint128 _toBorrow
    ) public {
        _maxWithdraw_withDebt(_collateral, _toBorrow, SAME_ASSET);
    }

    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxWithdraw_withDebt_2tokens_fuzz(
        uint128 _collateral,
        uint128 _toBorrow
    ) public {
        _maxWithdraw_withDebt(_collateral, _toBorrow, TWO_ASSETS);
    }

    function _maxWithdraw_withDebt(uint128 _collateral, uint128 _toBorrow, bool _sameAsset) private {
        _createDebtOnSilo1(_collateral, _toBorrow, _sameAsset);

        ISilo collateralSilo = _sameAsset ? silo1 : silo0;

        uint256 maxWithdraw = collateralSilo.maxWithdraw(borrower);
        assertLt(maxWithdraw, _collateral, "with debt you can not withdraw all");

        emit log_named_decimal_uint("LTV", collateralSilo.getLtv(borrower), 16);

        _assertBorrowerCanNotWithdrawMore(maxWithdraw, 3, _sameAsset);
        _assertMaxWithdrawIsZeroAtTheEnd(_sameAsset);
    }

    /*
    forge test -vv --ffi --mt test_maxWithdraw_withDebtAndNotEnoughLiquidity_
    */
    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxWithdraw_withDebtAndNotEnoughLiquidity_1token_fuzz(
        uint128 _collateral,
        uint128 _toBorrow,
        uint64 _percentToBorrowOnSilo0
    ) public {
        // (uint128 _collateral, uint128 _toBorrow, uint64 _percentToBorrowOnSilo0) = (27114386650, 1, 18440395);
        _maxWithdraw_withDebtAndNotEnoughLiquidity(_collateral, _toBorrow, _percentToBorrowOnSilo0, SAME_ASSET);
    }

    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxWithdraw_withDebtAndNotEnoughLiquidity_2tokens_fuzz(
        uint128 _collateral,
        uint128 _toBorrow,
        uint64 _percentToBorrowOnSilo0
    ) public {
        _maxWithdraw_withDebtAndNotEnoughLiquidity(_collateral, _toBorrow, _percentToBorrowOnSilo0, TWO_ASSETS);
    }

    function _maxWithdraw_withDebtAndNotEnoughLiquidity(
        uint128 _collateral,
        uint128 _toBorrow,
        uint64 _percentToBorrowOnSilo0,
        bool _sameAsset
    ) private {
        vm.assume(_percentToBorrowOnSilo0 <= 1e18);

        _createDebtOnSilo1(_collateral, _toBorrow, _sameAsset);

        ISilo collateralSilo = _sameAsset ? silo1 : silo0;

        uint256 borrowOnSilo0 = collateralSilo.getCollateralAssets() * _percentToBorrowOnSilo0 / 1e18;

        emit log_named_decimal_uint("_percentToBorrowOnSilo0", _percentToBorrowOnSilo0, 18);
        emit log_named_decimal_uint("borrowOnSilo0", borrowOnSilo0, 18);

        if (borrowOnSilo0 > 0) {
            address any = makeAddr("yet another user");
            bool collateralSiloSameToken = _sameAsset && address(collateralSilo) == address(silo0);
            _depositCollateral(borrowOnSilo0 * 2, any, !collateralSiloSameToken);
            vm.prank(any);
            collateralSilo.borrow(borrowOnSilo0, any, any, _sameAsset);
            emit log_named_decimal_uint("LTV any", silo1.getLtv(any), 16);
        }

        uint256 maxWithdraw = collateralSilo.maxWithdraw(borrower);
        assertLt(maxWithdraw, _collateral, "with debt you can not withdraw all");

        emit log_named_decimal_uint("LTV", silo1.getLtv(borrower), 16);

        _assertBorrowerCanNotWithdrawMore(maxWithdraw, 3, _sameAsset);
        _assertMaxWithdrawIsZeroAtTheEnd(_sameAsset);
    }

    /*
    forge test -vv --ffi --mt test_maxWithdraw_whenInterest_
    */
    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxWithdraw_whenInterest_1token_fuzz(
        uint128 _collateral,
        uint128 _toBorrow
    ) public {
        _maxWithdraw_whenInterest(_collateral, _toBorrow, SAME_ASSET);
    }

    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxWithdraw_whenInterest_2tokens_fuzz(
        uint128 _collateral,
        uint128 _toBorrow
    ) public {
        _maxWithdraw_whenInterest(_collateral, _toBorrow, TWO_ASSETS);
    }

    function _maxWithdraw_whenInterest(uint128 _collateral, uint128 _toBorrow, bool _sameAsset) private {
        _createDebtOnSilo1(_collateral, _toBorrow, _sameAsset);

        vm.warp(block.timestamp + 100 days);

        ISilo collateralSilo = _sameAsset ? silo1 : silo0;
        uint256 maxWithdraw = collateralSilo.maxWithdraw(borrower);
        assertLt(maxWithdraw, _collateral, "with debt you can not withdraw all");

        emit log_named_decimal_uint("LTV before withdraw", silo1.getLtv(borrower), 16);
        emit log_named_uint("maxWithdraw", maxWithdraw);

        _assertBorrowerCanNotWithdrawMore(maxWithdraw, 3, _sameAsset);
        _assertMaxWithdrawIsZeroAtTheEnd(1, _sameAsset);
    }

    /*
    forge test -vv --ffi --mt test_maxWithdraw_bothSilosWithInterest_
    */
    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxWithdraw_bothSilosWithInterest_1token_fuzz(
        uint128 _collateral,
        uint128 _toBorrow
    ) public {
        // (uint128 _collateral, uint128 _toBorrow) = (13637, 380);
        _maxWithdraw_bothSilosWithInterest(_collateral, _toBorrow, SAME_ASSET);
    }

    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxWithdraw_bothSilosWithInterest_2tokens_fuzz(
        uint128 _collateral,
        uint128 _toBorrow
    ) public {
        _maxWithdraw_bothSilosWithInterest(_collateral, _toBorrow, TWO_ASSETS);
    }

    function _maxWithdraw_bothSilosWithInterest(uint128 _collateral, uint128 _toBorrow, bool _sameAsset) private {
        _createDebtOnSilo0(_collateral, _toBorrow, _sameAsset);
        _createDebtOnSilo1(_collateral, _toBorrow, _sameAsset);

        vm.warp(block.timestamp + 100 days);

        ISilo collateralSilo = _sameAsset ? silo1 : silo0;
        uint256 maxWithdraw = collateralSilo.maxWithdraw(borrower);
        assertLt(maxWithdraw, _collateral, "with debt you can not withdraw all");

        emit log_named_decimal_uint("LTV before withdraw", silo1.getLtv(borrower), 16);
        emit log_named_uint("maxWithdraw", maxWithdraw);

        _assertBorrowerCanNotWithdrawMore(maxWithdraw, 4, _sameAsset);
        _assertMaxWithdrawIsZeroAtTheEnd(1, _sameAsset);
    }

    function _assertBorrowerHasNothingToWithdraw() internal {
        (, address collateralShareToken, ) = silo0.config().getShareTokens(address(silo0));

        assertEq(silo0.maxWithdraw(borrower), 0, "expect maxWithdraw to be 0");
        assertEq(IShareToken(collateralShareToken).balanceOf(borrower), 0, "expect share balance to be 0");
    }

    function _assertBorrowerCanNotWithdrawMore(uint256 _maxWithdraw, bool _sameAsset) internal {
        _assertBorrowerCanNotWithdrawMore(_maxWithdraw, 1, _sameAsset);
    }

    function _assertBorrowerCanNotWithdrawMore(uint256 _maxWithdraw, uint256 _underestimate, bool _sameAsset) internal {
        assertGt(_underestimate, 0, "_underestimate must be at least 1");

        emit log_named_uint("=== QA [_assertBorrowerCanNotWithdrawMore] _maxWithdraw:", _maxWithdraw);
        emit log_named_uint("=== QA [_assertBorrowerCanNotWithdrawMore] _underestimate:", _underestimate);

        ISilo collateralSilo = _sameAsset ? silo1 : silo0;

        if (_maxWithdraw > 0) {
            vm.prank(borrower);
            collateralSilo.withdraw(_maxWithdraw, borrower, borrower);
            emit log_named_decimal_uint("[_assertBorrowerCanNotWithdrawMore] LTV", silo1.getLtv(borrower), 16);
        }

        bool isSolvent = collateralSilo.isSolvent(borrower);

        if (!isSolvent) {
            assertEq(_maxWithdraw, 0, "if user is insolvent, MAX should be always 0");
        }

        uint256 counterExample = isSolvent ? _underestimate : 1;
        emit log_named_uint("=========== [counterexample] testing counterexample for maxWithdraw with", counterExample);

        vm.prank(borrower);
        vm.expectRevert();
        collateralSilo.withdraw(counterExample, borrower, borrower);
    }

    function _assertMaxWithdrawIsZeroAtTheEnd(bool _sameAsset) internal {
        _assertMaxWithdrawIsZeroAtTheEnd(0, _sameAsset);
    }

    function _assertMaxWithdrawIsZeroAtTheEnd(uint256 _underestimate, bool _sameAsset) internal {
        emit log_named_uint("================= _assertMaxWithdrawIsZeroAtTheEnd ================= +/-", _underestimate);

        ISilo collateralSilo = _sameAsset ? silo1 : silo0;
        uint256 maxWithdraw = collateralSilo.maxWithdraw(borrower);

        assertLe(
            maxWithdraw,
            _underestimate,
            string.concat("at this point max should return 0 +/-", string(abi.encodePacked(_underestimate)))
        );
    }
}
