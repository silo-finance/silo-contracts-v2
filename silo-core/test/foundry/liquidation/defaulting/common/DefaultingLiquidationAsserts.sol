// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

import {DefaultingLiquidationHelpers} from "./DefaultingLiquidationHelpers.sol";

abstract contract DefaultingLiquidationAsserts is DefaultingLiquidationHelpers {
    function _assertNoShareTokens(ISilo _silo, address _user) internal view {
        console2.log(
            "asserting no share tokens for silo %s, user %s", vm.getLabel(address(_silo)), vm.getLabel(_user)
        );
        (address collateralShareToken, address protectedShareToken, address debtShareToken) =
            siloConfig.getShareTokens(address(_silo));

        assertEq(IShareToken(protectedShareToken).balanceOf(_user), 0, "[_assertNoShareTokens] protected");
        assertEq(IShareToken(collateralShareToken).balanceOf(_user), 0, "[_assertNoShareTokens] collateral");
        assertEq(IShareToken(debtShareToken).balanceOf(_user), 0, "[_assertNoShareTokens] debt");
    }

    function _assertWithdrawableFees() internal {
        silo0.withdrawFees();
        silo1.withdrawFees();
    }

    function _assertEveryoneCanExit(ISilo _silo) internal {
        assertGt(depositors.length, 0, "[_assertEveryoneCanExit] no depositors");

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

    function _exitSilo() internal {
        _assertEveryoneCanExit(silo0);
        _assertEveryoneCanExit(silo1);
        _assertWithdrawableFees();

        _assertShareTokensAreEmpty(silo0);
        _assertShareTokensAreEmpty(silo1);
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
