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
    /// forge-config: core.fuzz.runs = 10000
    function test_maxWithdraw_deposit_fuzz(uint128 _assets) public {
        vm.assume(_assets > 0);
        _deposit(_assets, borrower);

        uint256 maxWithdraw = silo0.maxWithdraw(borrower);
        assertEq(maxWithdraw, _assets, "max withdraw == _assets if no interest");

        vm.prank(borrower);
        _withdraw(maxWithdraw, borrower);

        _assertBorrowerHasNothingToWithdraw();
    }

    /*
    forge test -vv --ffi --mt test_maxWithdraw_whenBorrow_fuzz
    */
    /// forge-config: core.fuzz.runs = 10000
    function test_maxWithdraw_whenBorrow_fuzz(
        uint128 _collateral
    ) public {
        // uint128 _collateral = 100;
        uint256 toBorrow = _collateral / 3;
        _createDebt(_collateral, toBorrow);

        uint256 maxWithdraw = silo0.maxWithdraw(borrower);
        assertLt(maxWithdraw, _collateral, "with debt you can not withdraw all");

        emit log_named_decimal_uint("LTV", silo1.getLtv(borrower), 18);

        if (maxWithdraw > 0) {
            _withdraw(maxWithdraw, borrower);
        }

        _assertBorrowerCanNotWithdrawMore();
    }

    /*
    forge test -vv --ffi --mt test_maxWithdraw_whenInterest_fuzz
    */
    /// forge-config: core.fuzz.runs = 10000
    function test_maxWithdraw_whenInterest_fuzz(
        uint128 _collateral
    ) public {
        // uint128 _collateral = 100;
        uint256 toBorrow = _collateral / 3;
        _createDebt(_collateral, toBorrow);

        vm.warp(block.timestamp + 100 days);

        uint256 maxWithdraw = silo0.maxWithdraw(borrower);
        assertLt(maxWithdraw, _collateral, "with debt you can not withdraw all");

        emit log_named_decimal_uint("LTV", silo1.getLtv(borrower), 18);

        if (maxWithdraw > 0) {
            _withdraw(maxWithdraw, borrower);
        }

        _assertBorrowerCanNotWithdrawMore();
    }

    function _createDebt(uint256 _collateral, uint256 _toBorrow) internal {
        vm.assume(_collateral > 0);
        vm.assume(_toBorrow > 0);

        _depositForBorrow(_collateral, depositor);
        _deposit(_collateral, borrower);
        _borrow(_toBorrow, borrower);
    }

    function _assertBorrowerHasNothingToWithdraw() internal {
        (, address collateralShareToken, ) = silo0.config().getShareTokens(address(silo0));

        assertEq(silo0.maxWithdraw(borrower), 0, "expect maxWithdraw to be 0");
        assertEq(IShareToken(collateralShareToken).balanceOf(borrower), 0, "expect share balance to be 0");
    }

    function _assertBorrowerCanNotWithdrawMore() internal {
        (, address collateralShareToken, ) = silo0.config().getShareTokens(address(silo0));

        assertEq(silo0.maxWithdraw(borrower), 0, "expect maxWithdraw to be 0");
        assertGt(IShareToken(collateralShareToken).balanceOf(borrower), 0, "expect share balance to be > 0");

        // TODO
//        vm.prank(borrower);
//        vm.expectRevert();
//        silo0.withdraw(1, borrower, borrower);
    }
}
