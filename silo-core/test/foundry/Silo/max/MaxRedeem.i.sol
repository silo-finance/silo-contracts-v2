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
    forge test -vv --ffi --mc MaxRedeemTest
*/
contract MaxRedeemTest is SiloLittleHelper, Test {
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
    forge test -vv --ffi --mt test_maxRedeem_zero
    */
    function test_maxRedeem_zero() public {
        uint256 maxRedeem = silo1.maxRedeem(borrower);
        assertEq(maxRedeem, 0, "nothing to redeem");
    }

    /*
    forge test -vv --ffi --mt test_maxRedeem_deposit_fuzz
    */
    /// forge-config: core.fuzz.runs = 1000
    function test_maxRedeem_deposit_fuzz(uint128 _assets) public {
        vm.assume(_assets > 0);
        _deposit(_assets, borrower);

        uint256 maxRedeem = silo0.maxRedeem(borrower);
        assertEq(maxRedeem, _assets, "max withdraw == _assets/shares if no interest");

        _redeem(maxRedeem, borrower);

        _assertBorrowerHasNothingToRedeem();
    }

    /*
    forge test -vv --ffi --mt test_maxRedeem_whenBorrow_fuzz
    */
    /// forge-config: core.fuzz.runs = 1000
    function test_maxRedeem_whenBorrow_fuzz(
        uint128 _collateral
    ) public {
        // uint128 _collateral = 100;
        uint256 toBorrow = _collateral / 3;
        uint256 shares = _createDebt(_collateral, toBorrow);

        uint256 maxRedeem = silo0.maxRedeem(borrower);
        // TODO for _collateral == 3, this is equal
        // assertLt(maxRedeem, shares, "with debt you can not withdraw all");

        emit log_named_decimal_uint("LTV", silo0.getLtv(borrower), 18);
        emit log_named_decimal_uint("shares", shares, 18);

        if (maxRedeem > 0) {
            _redeem(maxRedeem, borrower);
        }

        _assertBorrowerCanNotWithdrawMore();
    }

    /*
    forge test -vv --ffi --mt test_maxRedeem_whenInterest_fuzz
    */
    /// forge-config: core.fuzz.runs = 1000
    function test_maxRedeem_whenInterest_fuzz(
        uint128 _collateral
    ) public {
        // uint128 _collateral = 100;
        uint256 toBorrow = _collateral / 3;
        uint256 shares = _createDebt(_collateral, toBorrow);

        vm.warp(block.timestamp + 100 days);

        uint256 maxRedeem = silo0.maxRedeem(borrower);
        // assertLt(maxRedeem, shares, "with debt you can not withdraw all"); TODO

        emit log_named_decimal_uint("LTV", silo1.getLtv(borrower), 18);

        if (maxRedeem > 0) {
            _redeem(maxRedeem, borrower);
        }

        _assertBorrowerCanNotWithdrawMore();
    }

    function _createDebt(uint256 _collateral, uint256 _toBorrow) internal returns (uint256 shares) {
        vm.assume(_collateral > 0);
        vm.assume(_toBorrow > 0);

        _depositForBorrow(_collateral, depositor);
        _deposit(_collateral, borrower);
        return _borrow(_toBorrow, borrower);
    }

    function _assertBorrowerHasNothingToRedeem() internal {
        assertTrue(silo0.isSolvent(borrower), "must stay solvent");

        (, address collateralShareToken, ) = silo0.config().getShareTokens(address(silo0));

        assertEq(silo0.maxRedeem(borrower), 0, "expect maxRedeem to be 0");
        assertEq(IShareToken(collateralShareToken).balanceOf(borrower), 0, "expect share balance to be 0");
    }

    function _assertBorrowerCanNotWithdrawMore() internal {
        assertTrue(silo0.isSolvent(borrower), "must stay solvent");

        (, address collateralShareToken, ) = silo0.config().getShareTokens(address(silo0));

        assertEq(silo0.maxRedeem(borrower), 0, "expect maxRedeem to be 0");
        assertGt(IShareToken(collateralShareToken).balanceOf(borrower), 0, "expect share balance to be > 0");

        // TODO
        // vm.prank(borrower);
        // vm.expectRevert();
        // silo0.withdraw(1, borrower, borrower);
    }
}
