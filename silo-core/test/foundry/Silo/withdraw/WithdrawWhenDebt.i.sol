// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";

import {SiloFixture} from "../../_common/fixtures/SiloFixture.sol";
import {MintableToken} from "../../_common/MintableToken.sol";
import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc WithdrawWhenDebtTest
*/
contract WithdrawWhenDebtTest is SiloLittleHelper, Test {
    using SiloLensLib for ISilo;

    ISiloConfig siloConfig;

    function setUp() public {
        siloConfig = _setUpLocalFixture();

        // we need to have something to borrow
        _depositForBorrow(0.5e18, address(1));

        _deposit(2e18, address(this), ISilo.AssetType.Collateral);
        _deposit(1e18, address(this), ISilo.AssetType.Protected);

        _borrow(0.1e18, address(this));
    }

    /*
    forge test -vv --ffi --mt test_withdraw_all_possible_Collateral
    */
    function test_withdraw_all_possible_Collateral() public {
        (address protectedShareToken, address collateralShareToken,) = siloConfig.getShareTokens(address(silo0));
        (,, address debtShareToken) = siloConfig.getShareTokens(address(silo1));

        // collateral

        uint256 maxWithdraw = silo0.maxWithdraw(address(this));
        assertEq(maxWithdraw, 2e18 - 1, "maxWithdraw, because we have protected (-1 for underestimation)");

        uint256 previewWithdraw = silo0.previewWithdraw(maxWithdraw);
        uint256 gotShares = _withdraw(maxWithdraw, address(this), ISilo.AssetType.Collateral);

        assertEq(silo0.maxWithdraw(address(this)), 0, "no collateral left");

        uint256 expectedProtectedWithdraw = 882352941176470588;
        uint256 expectedCollateralLeft = 1e18 - expectedProtectedWithdraw;
        assertLe(0.1e18 * 1e18 / expectedCollateralLeft, 0.85e18, "LTV holds");

        assertEq(silo0.maxWithdraw(address(this), ISilo.AssetType.Protected), expectedProtectedWithdraw, "protected maxWithdraw");
        assertEq(previewWithdraw, gotShares, "previewWithdraw");

        assertEq(IShareToken(debtShareToken).balanceOf(address(this)), 0.1e18, "debtShareToken");
        assertEq(IShareToken(protectedShareToken).balanceOf(address(this)), 1e18, "protectedShareToken stays the same");
        assertLe(IShareToken(collateralShareToken).balanceOf(address(this)), 1, "collateral burned");

        assertLe(
            silo0.getCollateralAssets(),
            1,
            "#1 CollateralAssets should be withdrawn (if we withdaw based on max assets, we can underestimate by 1)"
        );

        // protected

        maxWithdraw = silo0.maxWithdraw(address(this), ISilo.AssetType.Protected);
        assertEq(maxWithdraw, expectedProtectedWithdraw, "maxWithdraw, protected");

        previewWithdraw = silo0.previewWithdraw(maxWithdraw, ISilo.AssetType.Protected);
        gotShares = _withdraw(maxWithdraw, address(this), ISilo.AssetType.Protected);

        assertEq(silo0.maxWithdraw(address(this), ISilo.AssetType.Protected), 0, "no protected withdrawn left");
        assertEq(previewWithdraw, gotShares, "protected previewWithdraw");

        assertEq(IShareToken(debtShareToken).balanceOf(address(this)), 0.1e18, "debtShareToken");
        assertEq(IShareToken(protectedShareToken).balanceOf(address(this)), expectedCollateralLeft, "protectedShareToken");

        assertLe(
            silo0.getCollateralAssets(),
            1,
            "#2 CollateralAssets should be withdrawn (if we withdaw based on max assets, we can underestimate by 1)"
        );

        assertTrue(silo0.isSolvent(address(this)), "must be solvent 1");
        assertTrue(silo1.isSolvent(address(this)), "must be solvent 2");
    }
}
