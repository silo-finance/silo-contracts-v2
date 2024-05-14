// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

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

    function _setUp(bool _sameAsset) private {
        siloConfig = _setUpLocalFixture();

        // we need to have something to borrow
        _depositForBorrow(0.5e18, address(1));

        _depositCollateral(2e18, address(this), _sameAsset, ISilo.CollateralType.Collateral);
        _depositCollateral(1e18, address(this), _sameAsset, ISilo.CollateralType.Protected);

        _borrow(0.1e18, address(this), _sameAsset);
    }

    /*
    forge test -vv --ffi --mt test_withdraw_all_possible_Collateral_
    */
    function test_withdraw_all_possible_Collateral_1token() public {
        _withdraw_all_possible_Collateral(SAME_ASSET);
    }

    function test_withdraw_all_possible_Collateral_2tokens() public {
        _withdraw_all_possible_Collateral(TWO_ASSETS);
    }

    function _withdraw_all_possible_Collateral(bool _sameAsset) private {
        _setUp(_sameAsset);
        address borrower = address(this);

        ISilo collateralSilo = _sameAsset ? silo1 : silo0;

        (
            address protectedShareToken, address collateralShareToken,
        ) = siloConfig.getShareTokens(address(collateralSilo));
        (,, address debtShareToken) = siloConfig.getShareTokens(address(silo1));

        // collateral

        uint256 maxWithdraw = collateralSilo.maxWithdraw(address(this));
        assertEq(maxWithdraw, 2e18 - 1, "maxWithdraw, because we have protected (-1 for underestimation)");

        uint256 previewWithdraw = collateralSilo.previewWithdraw(maxWithdraw);
        uint256 gotShares = collateralSilo.withdraw(maxWithdraw, borrower, borrower, ISilo.CollateralType.Collateral);

        assertEq(collateralSilo.maxWithdraw(address(this)), 0, "no collateral left");

        // you can withdraw more because interest are smaller
        uint256 expectedProtectedWithdraw = _sameAsset ? 894736842105263157 : 882352941176470588;
        uint256 expectedCollateralLeft = 1e18 - expectedProtectedWithdraw;
        assertLe(0.1e18 * 1e18 / expectedCollateralLeft, _sameAsset ? 0.95e18 : 0.85e18, "LTV holds");

        assertTrue(collateralSilo.isSolvent(address(this)), "must stay solvent");

        assertEq(
            collateralSilo.maxWithdraw(address(this), ISilo.CollateralType.Protected),
            expectedProtectedWithdraw,
            "protected maxWithdraw"
        );
        assertEq(previewWithdraw, gotShares, "previewWithdraw");

        assertEq(IShareToken(debtShareToken).balanceOf(address(this)), 0.1e18, "debtShareToken");
        assertEq(IShareToken(protectedShareToken).balanceOf(address(this)), 1e18, "protectedShareToken stays the same");
        assertLe(IShareToken(collateralShareToken).balanceOf(address(this)), 1, "collateral burned");

        assertLe(
            collateralSilo.getCollateralAssets(),
            1 + (_sameAsset ? 0.5e18 : 0), // there is additional collateral
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
            expectedCollateralLeft,
            "protectedShareToken"
        );

        assertLe(
            collateralSilo.getCollateralAssets(),
            1 + (_sameAsset ? 0.5e18 : 0), // there is additional collateral
            "#2 CollateralAssets should be withdrawn (if we withdraw based on max assets, we can underestimate by 1)"
        );

        assertTrue(collateralSilo.isSolvent(address(this)), "must be solvent 1");
        assertTrue(silo1.isSolvent(address(this)), "must be solvent 2");
    }
}
