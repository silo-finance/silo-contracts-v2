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
import {SiloFixture, SiloConfigOverride} from "../../_common/fixtures/SiloFixture.sol";

/*
    forge test -vv --ffi --mc BorrowIntegrationTest
*/
contract BorrowImmediateBadDebtTest is SiloLittleHelper, Test {
    using SiloLensLib for ISilo;
    using Strings for uint256;

    ISiloConfig siloConfig;

    /*
        forge test -vv --ffi --mt test_borrow_1wei_
    */
    function test_borrow_1wei_18_18_1token() public {
        _borrow_1wei(SAME_ASSET, 18, 18);
    }

    function test_borrow_1wei_6_6_1token() public {
        _borrow_1wei(SAME_ASSET, 6, 6);
    }

    function test_borrow_1wei_18_18_2tokens() public {
        _borrow_1wei(!SAME_ASSET, 18, 18);
    }

    function test_borrow_1wei_6_6_2tokens() public {
        _borrow_1wei(!SAME_ASSET, 6, 6);
    }

    /*
        forge test -vv --ffi --mt test_borrow_80wei_
    */
    function test_borrow_80wei_6_6_2tokens() public {
        _borrow_80wei(!SAME_ASSET, 6, 6);
    }

    function _borrow_1wei(bool _sameAsset, uint8 _decimals0, uint8 _decimals1) private {
        _setUp(_decimals0, _decimals1);

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
                string.concat("it takes over ", (solvencyTime / 60 / 60 / 24).toString()," days to be insolvent")
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

    function _borrow_80wei(bool _sameAsset, uint8 _decimals0, uint8 _decimals1) private {
        _setUp(_decimals0, _decimals1);

        uint256 assets = 75;
        address borrower = address(this);

        if (!_sameAsset) _depositForBorrow(assets, makeAddr("depositor"));

        _depositCollateral(100, borrower, _sameAsset);
        uint256 borrowShares = _borrow(assets, borrower, _sameAsset);

        vm.prank(borrower);
        silo0.withdraw(11, borrower, borrower); // bring LTV just below LT

        uint256 ltvBefore = silo1.getLtv(borrower);
        assertEq(ltvBefore, 842696629213483147, "LTV is just below LT");

        ISilo.UtilizationData memory data = silo1.utilizationData();

        if (_sameAsset) {
            assertEq(data.debtAssets * 1e18 / data.collateralAssets, 0.5e18, "50% utilization for same asset");
        } else {
            assertEq(data.debtAssets * 1e18 / data.collateralAssets, 1e18, "100% utilization");
        }

        uint256 solvencyTime = 1 days;
        vm.warp(block.timestamp + solvencyTime);
        emit log_named_decimal_uint("LTV after solvencyTime", silo1.getLtv(borrower), 18);
        assertTrue(silo1.isSolvent(borrower), "user must be still solvent");

        uint256 insolventTime = solvencyTime + 1 days;
        vm.warp(block.timestamp + 1 days);
        emit log_named_decimal_uint("LTV after some time", silo1.getLtv(borrower), 18);

        if (_sameAsset) {
            // for same asset it takes LONG time for position to grow to bad debt
        } else {
            assertTrue(
                !silo1.isSolvent(borrower),
                string.concat("it takes over ", (solvencyTime / 60 / 60 / 24).toString()," days to be insolvent")
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
            assertEq(silo1.getLtv(borrower), 85.101123595505617978e18, "[1y] LTV 850%");
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
            assertEq(silo1.getLtv(borrower), 169.370786516853932585e18, "[2y] LTV 1600%");
        }
    }

    function _setUp(uint8 _decimals0, uint8 _decimals1) private {
        token0 = new MintableToken(_decimals0);
        token1 = new MintableToken(_decimals1);

        SiloFixture siloFixture = new SiloFixture();
        SiloConfigOverride memory overrides;
        overrides.token0 = address(token0);
        overrides.token1 = address(token1);
        (, silo0, silo1,,, partialLiquidation) = siloFixture.deploy_local(overrides);
    }
}
