// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {IERC20Errors} from "openzeppelin5/interfaces/draft-IERC6093.sol";
import {Strings} from "openzeppelin5/utils/Strings.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";
import {SiloERC4626Lib} from "silo-core/contracts/lib/SiloERC4626Lib.sol";
import {AssetTypes} from "silo-core/contracts/lib/AssetTypes.sol";

import {MintableToken} from "../../_common/MintableToken.sol";
import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc BorrowIntegrationTest
*/
contract BorrowImmediateBadDebtTest is SiloLittleHelper, Test {
    using SiloLensLib for ISilo;
    using Strings for uint256;

    ISiloConfig siloConfig;

    function setUp() public {
        siloConfig = _setUpLocalFixture();

        assertTrue(siloConfig.getConfig(address(silo0)).maxLtv != 0, "we need borrow to be allowed");
    }

    /*
        forge test -vv --ffi --mt test_borrow_1wei_
    */
    function test_borrow_1wei_1token() public {
        _borrow_1wei(SAME_ASSET);
    }

    function test_borrow_1wei_2tokens() public {
        _borrow_1wei(!SAME_ASSET);
    }

    function _borrow_1wei(bool _sameAsset) private {
        uint256 assets = 1;
        address borrower = address(this);

        if (!_sameAsset) _depositForBorrow(assets, makeAddr("depositor"));

        _depositCollateral(2, borrower, _sameAsset);
        uint256 borrowShares = _borrow(assets, borrower, _sameAsset);

        uint256 ltvBefore = silo1.getLtv(borrower);
        assertEq(ltvBefore, 0.5e18, "LTV is 50%");

        ISilo.UtilizationData memory data = silo1.utilizationData();

        if (_sameAsset) {
            assertEq(data.debtAssets * 1e18 / data.collateralAssets, 0.5e18, "50% utilization for same asset");
        } else {
            assertEq(data.debtAssets * 1e18 / data.collateralAssets, 1e18, "100% utilization");
        }

//        vm.prank(borrower);
//        silo1.withdraw(1, borrower, borrower);
//        emit log_named_uint("LTV after withdraw", silo1.getLtv(borrower));

        uint256 solvencyTime = 8 days;
        vm.warp(block.timestamp + solvencyTime);
        emit log_named_decimal_uint("LTV after solvencyTime", silo1.getLtv(borrower), 18);
        assertTrue(silo1.isSolvent(borrower));

        uint256 insolventTime = solvencyTime + 1 days;
        vm.warp(block.timestamp + 1 days);
        emit log_named_decimal_uint("LTV after some time", silo1.getLtv(borrower), 18);

        if (_sameAsset) {
            // for same asset it takes LONG time for position to grow to bad debt
        } else {
            assertTrue(
                !silo1.isSolvent(borrower),
                string.concat("it takes ", (insolventTime / 60 / 60 / 24).toString()," days to be insolvent")
            );
        }

        vm.warp(block.timestamp + 365 days - insolventTime);

        emit log_named_decimal_uint("[1y] LTV after 1y", silo1.getLtv(borrower), 18);
        emit log_named_uint("[1y] current debt", silo1.previewRepayShares(borrowShares));
        (uint256 collateralToLiquidate, uint256 debtToRepay) = partialLiquidation.maxLiquidation(address(silo1), borrower);

        emit log_named_uint("[1y] collateralToLiquidate", collateralToLiquidate);
        emit log_named_uint("[1y] debtToRepay", debtToRepay);

        if (_sameAsset) {
            assertEq(silo1.getLtv(borrower), ltvBefore, "[1y] LTV the same for same asset");
        } else {
            assertEq(silo1.getLtv(borrower), ltvBefore * 100, "[1y] LTV x100");
        }

        vm.warp(block.timestamp + 365 days);

        emit log_named_decimal_uint("[2y] LTV after 2y", silo1.getLtv(borrower), 18);
        emit log_named_uint("[2y] current debt", silo1.previewRepayShares(borrowShares));
        (collateralToLiquidate, debtToRepay) = partialLiquidation.maxLiquidation(address(silo1), borrower);

        emit log_named_uint("[2y] collateralToLiquidate", collateralToLiquidate);
        emit log_named_uint("[2y] debtToRepay", debtToRepay);

        if (_sameAsset) {
            assertEq(silo1.getLtv(borrower), ltvBefore, "[2y] LTV the same for same asset");
        } else {
            assertEq(silo1.getLtv(borrower), ltvBefore * 200, "[2y] LTV x200");
        }
    }
}
