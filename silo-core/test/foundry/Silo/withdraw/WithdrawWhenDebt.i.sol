// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";
import {SiloMathLib} from "silo-core/contracts/lib/SiloMathLib.sol";

import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc WithdrawWhenDebtTest
*/
contract WithdrawWhenDebtTest is SiloLittleHelper, Test {
    using SiloLensLib for ISilo;

    ISiloConfig siloConfig;

    function _setUp() private {
        siloConfig = _setUpLocalFixture();

        // we need to have something to borrow
        _depositForBorrow(0.5e18, address(1));

        _deposit(2e18, address(this), ISilo.CollateralType.Collateral);
        _deposit(1e18, address(this), ISilo.CollateralType.Protected);

        _borrow(0.1e18, address(this));
    }

    /*
    forge test -vv --ffi --mt test_withdraw_all_possible_Collateral_
    */
    function test_withdraw_all_possible_Collateral_1token() public {
        _withdraw_all_possible_Collateral();
    }

    function _withdraw_all_possible_Collateral() private {
        _setUp();
        address borrower = address(this);

        ISilo collateralSilo = silo0;

        (
            address protectedShareToken, address collateralShareToken,
        ) = siloConfig.getShareTokens(address(collateralSilo));
        (,, address debtShareToken) = siloConfig.getShareTokens(address(silo1));

        // collateral

        uint256 maxWithdraw = collateralSilo.maxWithdraw(address(this));
        assertEq(maxWithdraw, 2e18, "maxWithdraw, because we have protected (-1 for underestimation)");

        uint256 previewWithdraw = collateralSilo.previewWithdraw(maxWithdraw);
        uint256 gotShares = collateralSilo.withdraw(maxWithdraw, borrower, borrower, ISilo.CollateralType.Collateral);

        assertEq(collateralSilo.maxWithdraw(address(this)), 0, "no collateral left");

        // you can withdraw more because interest are smaller
        uint256 expectedProtectedWithdraw = 882352941176470588;
        uint256 expectedCollateralLeft = 1e18 - expectedProtectedWithdraw;
        assertLe(0.1e18 * 1e18 / expectedCollateralLeft, 0.85e18, "LTV holds");

        assertTrue(collateralSilo.isSolvent(address(this)), "must stay solvent");

        assertEq(
            collateralSilo.maxWithdraw(address(this), ISilo.CollateralType.Protected),
            expectedProtectedWithdraw,
            "protected maxWithdraw"
        );
        assertEq(previewWithdraw, gotShares, "previewWithdraw");

        assertEq(IShareToken(debtShareToken).balanceOf(address(this)), 0.1e18, "debtShareToken");
        assertEq(IShareToken(protectedShareToken).balanceOf(address(this)), 1e18 * SiloMathLib._DECIMALS_OFFSET_POW, "protectedShareToken stays the same");
        assertLe(IShareToken(collateralShareToken).balanceOf(address(this)), 1 * SiloMathLib._DECIMALS_OFFSET_POW, "collateral burned");

        assertLe(
            collateralSilo.getCollateralAssets(),
            1,
            "#1 CollateralAssets should be withdrawn (if we withdraw based on max assets, we can underestimate by 1)"
        );

        // protected

        maxWithdraw = collateralSilo.maxWithdraw(address(this), ISilo.CollateralType.Protected);
        assertEq(maxWithdraw, expectedProtectedWithdraw, "maxWithdraw, protected");

        previewWithdraw = collateralSilo.previewWithdraw(maxWithdraw, ISilo.CollateralType.Protected);
        gotShares = collateralSilo.withdraw(maxWithdraw, borrower, borrower, ISilo.CollateralType.Protected);

        assertEq(
            collateralSilo.maxWithdraw(address(this), ISilo.CollateralType.Protected),
            0,
            "no protected withdrawn left"
        );

        assertEq(previewWithdraw, gotShares, "protected previewWithdraw");

        assertEq(IShareToken(debtShareToken).balanceOf(address(this)), 0.1e18, "debtShareToken");

        assertEq(
            IShareToken(protectedShareToken).balanceOf(address(this)),
            expectedCollateralLeft * SiloMathLib._DECIMALS_OFFSET_POW,
            "protectedShareToken"
        );

        assertLe(
            collateralSilo.getCollateralAssets(),
            1,
            "#2 CollateralAssets should be withdrawn (if we withdraw based on max assets, we can underestimate by 1)"
        );

        assertTrue(collateralSilo.isSolvent(address(this)), "must be solvent 1");
        assertTrue(silo1.isSolvent(address(this)), "must be solvent 2");
    }
}
