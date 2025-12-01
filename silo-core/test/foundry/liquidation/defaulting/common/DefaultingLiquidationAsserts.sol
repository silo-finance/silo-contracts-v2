// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

import {DefaultingLiquidationHelpers} from "./DefaultingLiquidationHelpers.sol";

abstract contract DefaultingLiquidationAsserts is DefaultingLiquidationHelpers {
    function _assertNoShareTokens(ISilo _silo, address _user, string memory _msg) internal view {
        _assertNoShareTokens(_silo, _user, false, _msg);
    }

    /// @param _allowForDust if true, we assert that the user is dead, NO dust is allowed
    /// why? eg. if we have 4000 shares this give us 11 assets ot withdraw, but when we convert
    /// 11 assets back to shares, we will get eg 3929 (with rounding up), bacause of that dust will be left
    /// this case was observed so far in same assets positions.
    function _assertNoShareTokens(ISilo _silo, address _user, bool _allowForDust, string memory _msg) internal view {
        console2.log("[_assertNoShareTokens] on silo %s for user %s", vm.getLabel(address(_silo)), vm.getLabel(_user));

        (address protectedShareToken, address collateralShareToken, address debtShareToken) =
            siloConfig.getShareTokens(address(_silo));

        uint256 balance = IShareToken(protectedShareToken).balanceOf(_user);

        if (_allowForDust) {
            assertEq(
                _silo.previewRedeem(balance, ISilo.CollateralType.Protected),
                0,
                string.concat("[_assertNoShareTokens] no protected dust: ", _msg)
            );
        } else {
            assertEq(balance, 0, string.concat("[_assertNoShareTokens] protected: ", _msg));
        }

        balance = IShareToken(collateralShareToken).balanceOf(_user);

        if (_allowForDust) {
            assertEq(
                _silo.previewRedeem(balance), 0, string.concat("[_assertNoShareTokens] no collateral dust: ", _msg)
            );
        } else {
            assertEq(balance, 0, string.concat("[_assertNoShareTokens] collateral: ", _msg));
        }

        balance = IShareToken(debtShareToken).balanceOf(_user);
        assertEq(balance, 0, string.concat("[_assertNoShareTokens] debt: ", _msg));
    }

    function _assertWithdrawableFees(ISilo _silo) internal {
        _silo.accrueInterest();

        _printFractions(_silo);

        (uint256 fees,,,,) = _silo.getSiloStorage();

        assertGt(
            fees,
            0,
            string.concat(
                "[_assertWithdrawableFees] expect fees to be greater than 0 for ", vm.getLabel(address(_silo))
            )
        );

        _silo.withdrawFees();
    }

    function _assertNoWithdrawableFees(ISilo _silo) internal {
        _silo.accrueInterest();

        vm.expectRevert(ISilo.EarnedZero.selector);
        _silo.withdrawFees();

        (uint256 fees,,,,) = _silo.getSiloStorage();
        assertEq(
            fees, 0, string.concat("[_assertNoWithdrawableFees] expect NO fees for ", vm.getLabel(address(_silo)))
        );
    }

    function _assertEveryoneCanExitFromSilo(ISilo _silo) internal {
        assertGt(depositors.length, 0, "[_assertEveryoneCanExit] no depositors to check");

        (address protectedShareToken,, address debtShareToken) = siloConfig.getShareTokens(address(_silo));

        assertEq(
            IShareToken(debtShareToken).totalSupply(),
            0,
            "[_assertEveryoneCanExit] debt must be 0 in order exit to work"
        );

        for (uint256 i; i < depositors.length; i++) {
            address depositor = depositors[i];
            _assertUserCanExit(_silo, depositor);
            // TODO once we figure out how to deal with leftover shares, we can uncomment this
            // _assertNoShareTokens(_silo, depositor, "_assertEveryoneCanExitFromSilo");
        }

        uint256 gaugeCollateral = _silo.balanceOf(address(gauge));
        uint256 gaugeProtected = IShareToken(protectedShareToken).balanceOf(address(gauge));

        console2.log("gaugeCollateral", gaugeCollateral);
        console2.log("gaugeProtected", gaugeProtected);

        assertEq(
            _silo.totalSupply(), gaugeCollateral, "[_assertEveryoneCanExit] silo should have only gauge collateral"
        );

        assertEq(
            IShareToken(protectedShareToken).totalSupply(),
            gaugeProtected,
            "[_assertEveryoneCanExit] protected share token should have only gauge protected"
        );
    }

    function _assertUserCanExit(ISilo _silo, address _user) internal {
        (address protectedShareToken,,) = siloConfig.getShareTokens(address(_silo));

        vm.startPrank(_user);
        uint256 balance = _silo.balanceOf(_user);
        uint256 redeemable = _silo.maxRedeem(_user);

        emit log_named_decimal_uint(
            string.concat("[", vm.getLabel(address(_silo)), "] ", vm.getLabel(_user), " collateral shares"),
            balance,
            21
        );
        emit log_named_decimal_uint("\tredeemable", redeemable, 21);
        if (redeemable != 0) _silo.redeem(redeemable, _user, _user);

        balance = IShareToken(protectedShareToken).balanceOf(_user);
        redeemable = _silo.maxRedeem(_user, ISilo.CollateralType.Protected);
        emit log_named_decimal_uint(
            string.concat("[", vm.getLabel(protectedShareToken), "] ", vm.getLabel(_user), " protected shares"),
            balance,
            21
        );
        emit log_named_decimal_uint("\tredeemable", redeemable, 21);
        if (redeemable != 0) _silo.redeem(redeemable, _user, _user, ISilo.CollateralType.Protected);
        vm.stopPrank();
    }

    function _assertShareTokensAreEmpty(ISilo _silo) internal view {
        (address protectedShareToken, address collateralShareToken, address debtShareToken) =
            siloConfig.getShareTokens(address(_silo));

        assertEq(
            IShareToken(protectedShareToken).balanceOf(address(this)),
            0,
            "[_assertShareTokensAreEmpty] protected share token should be 0"
        );
        assertEq(
            IShareToken(collateralShareToken).balanceOf(address(this)),
            0,
            "[_assertShareTokensAreEmpty] collateral share token should be 0"
        );
        assertEq(
            IShareToken(debtShareToken).balanceOf(address(this)),
            0,
            "[_assertShareTokensAreEmpty] debt share token should be 0"
        );
    }
}
