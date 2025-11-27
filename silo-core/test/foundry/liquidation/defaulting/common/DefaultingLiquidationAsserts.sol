// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

import {DefaultingLiquidationHelpers} from "./DefaultingLiquidationHelpers.sol";

abstract contract DefaultingLiquidationAsserts is DefaultingLiquidationHelpers {
    function _assertNoShareTokens(ISilo _silo, address _user) internal view {
        _assertNoShareTokens(_silo, _user, false);
    }

    /// @param _allowForDust if true, we assert that the user is dead, NO dust is allowed
    /// why? eg. if we have 4000 shares this give us 11 assets ot withdraw, but when we convert
    /// 11 assets back to shares, we will get eg 3929 (with rounding up), bacause of that dust will be left
    /// this case was observed so far in same assets positions.
    function _assertNoShareTokens(ISilo _silo, address _user, bool _allowForDust) internal view {
        console2.log(
            "asserting no share tokens for silo %s, user %s", vm.getLabel(address(_silo)), vm.getLabel(_user)
        );

        (address collateralShareToken, address protectedShareToken, address debtShareToken) =
            siloConfig.getShareTokens(address(_silo));

        uint256 balance = IShareToken(protectedShareToken).balanceOf(_user);

        if (_allowForDust) {
            assertEq(
                _silo.previewRedeem(balance, ISilo.CollateralType.Protected),
                0,
                "[_assertNoShareTokens] no protected dust"
            );
        } else {
            assertEq(balance, 0, "[_assertNoShareTokens] protected");
        }

        balance = IShareToken(collateralShareToken).balanceOf(_user);

        if (_allowForDust) {
            assertEq(_silo.previewRedeem(balance), 0, "[_assertNoShareTokens] no collateral dust");
        } else {
            assertEq(balance, 0, "[_assertNoShareTokens] collateral");
        }

        balance = IShareToken(debtShareToken).balanceOf(_user);
        assertEq(balance, 0, "[_assertNoShareTokens] debt");
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

    function _assertEveryoneCanExit() internal {
        (ISilo collateralSilo, ISilo debtSilo) = _getSilos();
        // assertGt(depositors.length, 0, "[_assertEveryoneCanExit] no depositors to check");

        _assertEveryoneCanExitFromSilo(collateralSilo);
        _assertEveryoneCanExitFromSilo(debtSilo);

        (address protectedShareToken,,) = siloConfig.getShareTokens(address(collateralSilo));

        uint256 gaugeCollateral = collateralSilo.balanceOf(address(gauge));
        uint256 gaugeProtected = IShareToken(protectedShareToken).balanceOf(address(gauge));

        assertEq(
            collateralSilo.totalSupply(),
            gaugeCollateral,
            "[_assertEveryoneCanExit] silo should have only gauge collateral"
        );
        assertEq(
            IShareToken(protectedShareToken).totalSupply(),
            gaugeProtected,
            "[_assertEveryoneCanExit] protected share token should have only gauge protected"
        );

        assertEq(debtSilo.totalSupply(), 0, "[_assertEveryoneCanExit] debt silo should have no shares, liquidity");
    }

    function _assertEveryoneCanExitFromSilo(ISilo _silo) internal {
        // assertGt(depositors.length, 0, "[_assertEveryoneCanExit] no depositors to check");

        (address protectedShareToken,,) = siloConfig.getShareTokens(address(_silo));

        for (uint256 i; i < depositors.length; i++) {
            address depositor = depositors[i];
            _assertUserCanExit(_silo, IShareToken(protectedShareToken), depositor);
        }
    }

    function _assertUserCanExit(ISilo _silo, IShareToken _protected, address _user) internal {
        vm.startPrank(_user);
        uint256 balance = _silo.balanceOf(_user);
        if (balance != 0) _silo.redeem(balance, _user, _user);

        balance = _protected.balanceOf(_user);
        if (balance != 0) _silo.withdraw(balance, _user, _user, ISilo.CollateralType.Protected);
        vm.stopPrank();

        _assertNoShareTokens(_silo, _user);
    }

    // function _exitSilo() internal {
    //     _assertEveryoneCanExit();
    //     _assertWithdrawableFees(silo0);
    //     _assertWithdrawableFees(silo1);

    //     _assertShareTokensAreEmpty(silo0);
    //     _assertShareTokensAreEmpty(silo1);
    // }

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
