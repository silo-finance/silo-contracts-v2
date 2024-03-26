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
    forge test -vv --ffi --mt test_maxWithdraw_deposit_fuzz
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

        _assertBorrowerCanNotWithdrawMore(maxWithdraw);
        _assertMaxWithdrawIsZeroAtTheEnd();
    }

    /*
    forge test -vv --ffi --mt test_maxWithdraw_withDebt_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxWithdraw_withDebt_fuzz(
        uint128 _collateral,
        uint128 _toBorrow
    ) public {
        // (uint128 _collateral, uint256 _toBorrow) = (5526, 1842);
        _createDebtOnSilo1(_collateral, _toBorrow);

        uint256 maxWithdraw = silo0.maxWithdraw(borrower);
        assertLt(maxWithdraw, _collateral, "with debt you can not withdraw all");

        emit log_named_decimal_uint("LTV", silo1.getLtv(borrower), 18);

        _assertBorrowerCanNotWithdrawMore(maxWithdraw, 3);
        _assertMaxWithdrawIsZeroAtTheEnd();
    }

    /*
    forge test -vv --ffi --mt test_maxWithdraw_withDebtAndNotEnoughLiquidity_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxWithdraw_withDebtAndNotEnoughLiquidity_fuzz(
        uint128 _collateral,
        uint128 _toBorrow,
        uint64 _percentToBorrowOnSilo0
    ) public {
        // (uint128 _collateral, uint256 _toBorrow, uint64 _percentToBorrowOnSilo0) = (90522, 7630, 1e18);
        vm.assume(_percentToBorrowOnSilo0 <= 1e18);

        _createDebtOnSilo1(_collateral, _toBorrow);
        uint256 borrowOnSilo0 = silo0.getCollateralAssets() * _percentToBorrowOnSilo0 / 1e18;

        if (borrowOnSilo0 > 0) {
            address any = makeAddr("yet another user");
            _depositForBorrow(borrowOnSilo0 * 2, any);
            vm.prank(any);
            silo0.borrow(borrowOnSilo0, any, any, false /* sameToken */);
        }

        uint256 maxWithdraw = silo0.maxWithdraw(borrower);
        assertLt(maxWithdraw, _collateral, "with debt you can not withdraw all");

        emit log_named_decimal_uint("LTV", silo1.getLtv(borrower), 18);

        _assertBorrowerCanNotWithdrawMore(maxWithdraw, 3);
        _assertMaxWithdrawIsZeroAtTheEnd();
    }

    /*
    forge test -vv --ffi --mt test_maxWithdraw_whenInterest_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxWithdraw_whenInterest_fuzz(
        uint128 _collateral,
        uint128 _toBorrow
    ) public {
//        (uint128 _collateral, uint128 _toBorrow) = (16278, 10070);
        _createDebtOnSilo1(_collateral, _toBorrow);

        vm.warp(block.timestamp + 100 days);

        uint256 maxWithdraw = silo0.maxWithdraw(borrower);
        assertLt(maxWithdraw, _collateral, "with debt you can not withdraw all");

        emit log_named_decimal_uint("LTV before withdraw", silo1.getLtv(borrower), 16);
        emit log_named_uint("maxWithdraw", maxWithdraw);

        _assertBorrowerCanNotWithdrawMore(maxWithdraw, 3);
        _assertMaxWithdrawIsZeroAtTheEnd(1);
    }

    /*
    forge test -vv --ffi --mt test_maxWithdraw_bothSilosWithInterest_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxWithdraw_bothSilosWithInterest_fuzz(
        uint128 _collateral,
        uint128 _toBorrow
    ) public {
//        (uint128 _collateral, uint128 _toBorrow) = (4323, 3821);
        _createDebtOnSilo0(_collateral, _toBorrow);
        _createDebtOnSilo1(_collateral, _toBorrow);

        vm.warp(block.timestamp + 100 days);

        uint256 maxWithdraw = silo0.maxWithdraw(borrower);
        assertLt(maxWithdraw, _collateral, "with debt you can not withdraw all");

        emit log_named_decimal_uint("LTV before withdraw", silo1.getLtv(borrower), 16);
        emit log_named_uint("maxWithdraw", maxWithdraw);

        _assertBorrowerCanNotWithdrawMore(maxWithdraw, 4);
        _assertMaxWithdrawIsZeroAtTheEnd(1);
    }

    function _assertBorrowerHasNothingToWithdraw() internal {
        (, address collateralShareToken, ) = silo0.config().getShareTokens(address(silo0));

        assertEq(silo0.maxWithdraw(borrower), 0, "expect maxWithdraw to be 0");
        assertEq(IShareToken(collateralShareToken).balanceOf(borrower), 0, "expect share balance to be 0");
    }

    function _assertBorrowerCanNotWithdrawMore(uint256 _maxWithdraw) internal {
        _assertBorrowerCanNotWithdrawMore(_maxWithdraw, 1);
    }

    function _assertBorrowerCanNotWithdrawMore(uint256 _maxWithdraw, uint256 _underestimate) internal {
        assertGt(_underestimate, 0, "_underestimate must be at least 1");

        emit log_named_uint("_maxWithdraw:", _maxWithdraw);

        if (_maxWithdraw > 0) {
            _withdraw(_maxWithdraw, borrower);
        }

        bool isSolvent = silo0.isSolvent(borrower);

        if (!isSolvent) {
            assertEq(_maxWithdraw, 0, "if user is insolvent, MAX should be always 0");
        }

        uint256 counterExample = isSolvent ? _underestimate : 1;
        emit log_named_uint("=========== [counterexample] testing counterexample for maxWithdraw with", counterExample);

        vm.prank(borrower);
        vm.expectRevert();
        silo0.withdraw(counterExample, borrower, borrower);
    }

    function _assertMaxWithdrawIsZeroAtTheEnd() internal {
        _assertMaxWithdrawIsZeroAtTheEnd(0);
    }

    function _assertMaxWithdrawIsZeroAtTheEnd(uint256 _underestimate) internal {
        emit log_named_uint("================= _assertMaxWithdrawIsZeroAtTheEnd ================= +/-", _underestimate);

        uint256 maxWithdraw = silo0.maxWithdraw(borrower);

        assertLe(
            maxWithdraw,
            _underestimate,
            string.concat("at this point max should return 0 +/-", string(abi.encodePacked(_underestimate)))
        );
    }
}
