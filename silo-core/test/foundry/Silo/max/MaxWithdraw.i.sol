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
    forge test -vv --ffi --mc MaxWithdrawTest
*/
contract MaxWithdrawTest is SiloLittleHelper, Test {
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
    forge test -vv --ffi --mt test_maxWithdraw_zero
    */
    function test_maxWithdraw_zero() public {
        uint256 maxWithdraw = silo1.maxWithdraw(borrower);
        assertEq(maxWithdraw, 0, "nothing to withdraw");
    }

    /*
    forge test -vv --ffi --mt test_maxWithdraw_deposit_fuzz
    */
    /// forge-config: core.fuzz.runs = 1000
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
    forge test -vv --ffi --mt test_maxWithdraw_whenBorrow_fuzz
    */
    /// forge-config: core.fuzz.runs = 1000
    function test_maxWithdraw_whenBorrow_fuzz(
        uint128 _collateral,
        uint128 _toBorrow
    ) public {
//        (uint128 _collateral, uint256 _toBorrow) = (5526, 1842);
        _createDebtSilo1(_collateral, _toBorrow);

        uint256 maxWithdraw = silo0.maxWithdraw(borrower);
        assertLt(maxWithdraw, _collateral, "with debt you can not withdraw all");

        emit log_named_decimal_uint("LTV", silo1.getLtv(borrower), 18);

        _assertBorrowerCanNotWithdrawMore(maxWithdraw, 2);
        _assertMaxWithdrawIsZeroAtTheEnd();
    }

    /*
    forge test -vv --ffi --mt test_maxWithdraw_whenInterest_fuzz
    */
    /// forge-config: core.fuzz.runs = 1000
    function test_maxWithdraw_whenInterest_fuzz(
        uint128 _collateral,
        uint128 _toBorrow
    ) public {
//        (uint128 _collateral, uint128 _toBorrow) = (16278, 10070);
        _createDebtSilo1(_collateral, _toBorrow);

        vm.warp(block.timestamp + 100 days);

        uint256 maxWithdraw = silo0.maxWithdraw(borrower);
        assertLt(maxWithdraw, _collateral, "with debt you can not withdraw all");

        emit log_named_decimal_uint("LTV before withdraw", silo1.getLtv(borrower), 16);
        emit log_named_uint("maxWithdraw", maxWithdraw);

        _assertBorrowerCanNotWithdrawMore(maxWithdraw, 2);
        _assertMaxWithdrawIsZeroAtTheEnd(1);
    }

    /*
    forge test -vv --ffi --mt test_maxWithdraw_bothSilosWithInterest_fuzz
    */
    /// forge-config: core.fuzz.runs = 1000
    function test_maxWithdraw_bothSilosWithInterest_fuzz(
        uint128 _collateral,
        uint128 _toBorrow
    ) public {
//        (uint128 _collateral, uint128 _toBorrow) = (4323, 3821);
        _createDebtSilo0(_collateral, _toBorrow);
        _createDebtSilo1(_collateral, _toBorrow);

        vm.warp(block.timestamp + 100 days);

        uint256 maxWithdraw = silo0.maxWithdraw(borrower);
        assertLt(maxWithdraw, _collateral, "with debt you can not withdraw all");

        emit log_named_decimal_uint("LTV before withdraw", silo1.getLtv(borrower), 16);
        emit log_named_uint("maxWithdraw", maxWithdraw);

        _assertBorrowerCanNotWithdrawMore(maxWithdraw, 2);
        _assertMaxWithdrawIsZeroAtTheEnd(1);
    }

    function _createDebtSilo1(uint256 _collateral, uint256 _toBorrow) internal {
        vm.assume(_toBorrow > 0);
        vm.assume(_collateral > _toBorrow);

        _depositForBorrow(_collateral, depositor);
        _deposit(_collateral, borrower);
        uint256 maxBorrow = silo1.maxBorrow(borrower);
        vm.assume(maxBorrow > 0);

        uint256 assets = _toBorrow > maxBorrow ? maxBorrow : _toBorrow;
        _borrow(assets, borrower);

        emit log_named_uint("[_createDebt] _collateral", _collateral);
        emit log_named_uint("[_createDebt] maxBorrow", maxBorrow);
        emit log_named_uint("[_createDebt] _toBorrow", _toBorrow);
        emit log_named_uint("[_createDebt] borrowed", assets);

        emit log_named_decimal_uint("LTV after borrow", silo1.getLtv(borrower), 16);
        assertEq(silo0.getLtv(borrower), silo1.getLtv(borrower), "LTV should be the same on both silos");

        _ensureBorrowerHasDebt(silo1, borrower);
    }

    function _createDebtSilo0(uint256 _collateral, uint256 _toBorrow) internal {
        vm.assume(_toBorrow > 0);
        vm.assume(_collateral > _toBorrow);

        address otherBorrower = makeAddr("other borrower");

        _deposit(_collateral, depositor);
        _depositForBorrow(_collateral, otherBorrower);
        uint256 maxBorrow = silo0.maxBorrow(otherBorrower);
        vm.assume(maxBorrow > 0);

        uint256 assets = _toBorrow > maxBorrow ? maxBorrow : _toBorrow;
        vm.prank(otherBorrower);
        silo0.borrow(assets, otherBorrower, otherBorrower);

        emit log_named_uint("[_createDebt] _collateral", _collateral);
        emit log_named_uint("[_createDebt] maxBorrow", maxBorrow);
        emit log_named_uint("[_createDebt] _toBorrow", _toBorrow);
        emit log_named_uint("[_createDebt] borrowed", assets);

        emit log_named_decimal_uint("LTV after borrow", silo0.getLtv(otherBorrower), 16);
        assertEq(silo0.getLtv(otherBorrower), silo1.getLtv(otherBorrower), "LTV should be the same on both silos");

        _ensureBorrowerHasDebt(silo0, otherBorrower);
    }

    function _ensureBorrowerHasDebt(ISilo _silo, address _borrower) internal {
        (,, address debtShareToken) = _silo.config().getShareTokens(address(_silo));

        assertGt(_silo.maxRepayShares(_borrower), 0, "expect debt");
        assertGt(IShareToken(debtShareToken).balanceOf(_borrower), 0, "expect debtShareToken balance > 0");
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

        if (_maxWithdraw > 0) {
            _withdraw(_maxWithdraw, borrower);
        }

        bool isSolvent = silo0.isSolvent(borrower);

        if (!isSolvent) {
            assertEq(_maxWithdraw, 0, "if user is insolvent, MAX should be always 0");
        }

        uint256 counterExample  = isSolvent ? _underestimate : 1;
        emit log_named_uint("=========== [counterexample] testing counterexample for maxWithdraw with", counterExample);

        // TODO
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
