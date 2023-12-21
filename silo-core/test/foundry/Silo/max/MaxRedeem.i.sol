// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;


import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";

import {MaxWithdrawCommon} from "./MaxWithdrawCommon.sol";

/*
    forge test -vv --ffi --mc MaxRedeemTest
*/
contract MaxRedeemTest is MaxWithdrawCommon {
    function setUp() public {
        _setUpLocalFixture(SiloConfigsNames.LOCAL_NO_ORACLE_NO_LTV_SILO);
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
    function test_maxRedeem_deposit_fuzz(
        uint112 _assets,
        uint16 _assets2
    ) public {
        vm.assume(_assets > 0);
        vm.assume(_assets2 > 0);

        _deposit(_assets, borrower);
        _deposit(_assets2, address(1)); // any

        uint256 maxRedeem = silo0.maxRedeem(borrower);
        assertEq(maxRedeem, _assets, "max withdraw == _assets/shares if no interest");

        _assertBorrowerCanNotRedeemMore(maxRedeem);
        _assertBorrowerHasNothingToRedeem();
    }

    /*
    forge test -vv --ffi --mt test_maxRedeem_whenBorrow_fuzz
    */
    /// forge-config: core.fuzz.runs = 1000
    function test_maxRedeem_whenBorrow_fuzz(
        uint128 _collateral,
        uint128 _toBorrow
    ) public {
//        (uint128 _collateral, uint256 _toBorrow) = (52874512, 1);
        _createDebtSilo1(_collateral, _toBorrow);

        uint256 maxRedeem = silo0.maxRedeem(borrower);

        (, address collateralShareToken, ) = silo0.config().getShareTokens(address(silo0));
        assertLt(maxRedeem, IShareToken(collateralShareToken).balanceOf(borrower), "with debt you can not withdraw all");

        emit log_named_decimal_uint("LTV", silo0.getLtv(borrower), 18);

        _assertBorrowerCanNotRedeemMore(maxRedeem, 2);
    }

    /*
    forge test -vv --ffi --mt test_maxRedeem_whenInterest_fuzz
    */
    /// forge-config: core.fuzz.runs = 1000
    function test_maxRedeem_whenInterest_fuzz(
        uint128 _collateral,
        uint128 _toBorrow
    ) public {
        // uint128 _collateral = 100;
        _createDebtSilo1(_collateral, _toBorrow);

        vm.warp(block.timestamp + 100 days);

        uint256 maxRedeem = silo0.maxRedeem(borrower);
        (, address collateralShareToken, ) = silo0.config().getShareTokens(address(silo0));
        assertLt(maxRedeem, IShareToken(collateralShareToken).balanceOf(borrower), "with debt you can not withdraw all");

        emit log_named_decimal_uint("LTV", silo1.getLtv(borrower), 18);

        _assertBorrowerCanNotRedeemMore(maxRedeem, 2);
    }

    /*
    forge test -vv --ffi --mt test_maxRedeem_bothSilosWithInterest_fuzz
    */
    /// forge-config: core.fuzz.runs = 1000
    function test_maxRedeem_bothSilosWithInterest_fuzz(
//        uint128 _collateral,
//        uint128 _toBorrow
    ) public {
        (uint128 _collateral, uint128 _toBorrow) = (21288, 4007);
        _createDebtSilo1(_collateral, _toBorrow);
        _createDebtSilo0(_collateral, _toBorrow);

        vm.warp(block.timestamp + 100 days);

        uint256 maxRedeem = silo0.maxRedeem(borrower);
        (, address collateralShareToken, ) = silo0.config().getShareTokens(address(silo0));
        assertLt(maxRedeem, IShareToken(collateralShareToken).balanceOf(borrower), "with debt you can not withdraw all");

        emit log_named_decimal_uint("LTV", silo1.getLtv(borrower), 18);

        _assertBorrowerCanNotRedeemMore(maxRedeem, 2);
    }

    function _assertBorrowerHasNothingToRedeem() internal {
        (, address collateralShareToken, ) = silo0.config().getShareTokens(address(silo0));

        assertEq(silo0.maxRedeem(borrower), 0, "expect maxRedeem to be 0");
        assertEq(IShareToken(collateralShareToken).balanceOf(borrower), 0, "expect share balance to be 0");
    }

    function _assertBorrowerCanNotRedeemMore(uint256 _maxRedeem) internal {
        _assertBorrowerCanNotRedeemMore(_maxRedeem, 1);
    }

    function _assertBorrowerCanNotRedeemMore(uint256 _maxRedeem, uint256 _underestimate) internal {
        assertGt(_underestimate, 0, "_underestimate must be at least 1");

        if (_maxRedeem > 0) {
            _redeem(_maxRedeem, borrower);
        }

        bool isSolvent = silo0.isSolvent(borrower);

        if (!isSolvent) {
            assertEq(_maxRedeem, 0, "if user is insolvent, MAX should be always 0");
        }

        uint256 counterExample  = isSolvent ? _underestimate : 1;
        emit log_named_uint("=========== [counterexample] testing counterexample for maxRedeem with", counterExample);

        vm.prank(borrower);
        vm.expectRevert();
        silo0.redeem(counterExample, borrower, borrower);
    }

    function _assertMaxRedeemIsZeroAtTheEnd() internal {
        _assertMaxRedeemIsZeroAtTheEnd(0);
    }

    function _assertMaxRedeemIsZeroAtTheEnd(uint256 _underestimate) internal {
        emit log_named_uint("================= _assertMaxRedeemIsZeroAtTheEnd ================= +/-", _underestimate);

        uint256 maxRedeem = silo0.maxRedeem(borrower);

        assertLe(
            maxRedeem,
            _underestimate,
            string.concat("at this point max should return 0 +/-", string(abi.encodePacked(_underestimate)))
        );
    }
}
