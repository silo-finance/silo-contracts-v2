// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";

import {MintableToken} from "../../_common/MintableToken.sol";
import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc PreviewWithdrawTest
*/
contract PreviewWithdrawTest is SiloLittleHelper, Test {
    uint256 constant DEPOSIT_BEFORE = 1e18 + 9876543211;

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
    forge test -vv --ffi --mt test_previewWithdraw_noInterestNoDebt_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 10000
    function test_previewWithdraw_noInterestNoDebt_fuzz(
        uint128 _assetsOrShares,
        bool _partial
    ) public {
        uint128 amountToUse = _partial ? uint128(uint256(_assetsOrShares) * 37 / 100) : _assetsOrShares;
        vm.assume(amountToUse > 0);

        ISilo.CollateralType assetType = _collateralType();

        // preview before deposit creation
        uint256 preview = _useRedeem()
            ? _silo().previewRedeem(amountToUse, assetType)
            : _silo().previewWithdraw(amountToUse, assetType);

        // first deposit AFTER preview
        _depositCollateral(_assetsOrShares, depositor, _sameAsset(), assetType);

        assertEq(preview, amountToUse, "previewWithdraw == assets == shares, when no interest");

        _assertPreviewWithdraw(preview, amountToUse);
    }

    /*
    forge test -vv --ffi --mt test_previewWithdraw_noDebt_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 10000
    function test_previewWithdraw_noDebt_fuzz(
        uint128 _assetsOrShares,
        bool _partial
    ) public {
        uint128 amountToUse = _partial ? uint128(uint256(_assetsOrShares) * 37 / 100) : _assetsOrShares;
        vm.assume(amountToUse > 0);

        ISilo.CollateralType assetType = _collateralType();

        _depositCollateral(uint256(_assetsOrShares) * 2 - (_assetsOrShares % 2), depositor, _sameAsset(), assetType);

        uint256 preview = _useRedeem()
            ? _silo().previewRedeem(amountToUse, assetType)
            : _silo().previewWithdraw(amountToUse, assetType);

        assertEq(preview, amountToUse, "previewWithdraw == assets == shares, when no interest");

        _assertPreviewWithdraw(preview, amountToUse);
    }

    /*
    forge test -vv --ffi --mt test_previewWithdraw_debt_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 10000
    function test_previewWithdraw_debt_fuzz(
        uint128 _assetsOrShares,
        bool _interest,
        bool _partial
    ) public {
        vm.assume(_assetsOrShares > 1); // can not create debt with 1 collateral
        uint128 amountToUse = _partial ? uint128(uint256(_assetsOrShares) * 37 / 100) : _assetsOrShares;
        vm.assume(amountToUse > 0);

        ISilo.CollateralType assetType = _collateralType();
        bool protectedType = assetType == ISilo.CollateralType.Protected;

        if (!_sameAsset() || protectedType) _depositForBorrow(_assetsOrShares, makeAddr("any"));
        // % 2 is to keep odd numbers
        _depositCollateral(uint256(_assetsOrShares) * 2 - _assetsOrShares % 2, depositor, _sameAsset(), assetType);
        _borrow(_assetsOrShares / 2 == 0 ? 1 : _assetsOrShares / 2, depositor, _sameAsset());

        if (_interest) vm.warp(block.timestamp + 100 days);

        uint256 preview = _useRedeem()
            ? _silo().previewRedeem(amountToUse, assetType)
            : _silo().previewWithdraw(amountToUse, assetType);

        if (!_interest || protectedType) {
            assertEq(preview, amountToUse, "previewWithdraw == assets == shares, when no interest");
        }

        _assertPreviewWithdraw(preview, amountToUse);
    }

    /*
    forge test -vv --ffi --mt test_previewWithdraw_debtOthers_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 10000
    function test_previewWithdraw_debtOthers_fuzz(
        uint64 _otherDeposit,
        uint64 _assetsOrShares,
        bool _interest,
        bool _partial
    ) public {
        vm.assume(_otherDeposit > 0);
        vm.assume(_assetsOrShares > 1); // can not create debt with 1 collateral
        uint128 amountToUse = _partial ? uint128(uint256(_assetsOrShares) * 37 / 100) : _assetsOrShares;
        vm.assume(amountToUse > 0);

        ISilo.CollateralType assetType = _collateralType();
        bool protectedType = assetType == ISilo.CollateralType.Protected;

        _depositCollateral(_otherDeposit, makeAddr("other"), _sameAsset(), assetType);

        if (!_sameAsset() || protectedType) _depositForBorrow(_assetsOrShares, makeAddr("any"));
        // % 2 is to keep odd numbers
        _depositCollateral(uint256(_assetsOrShares) * 2 - _assetsOrShares % 2, depositor, _sameAsset(), assetType);
        _borrow(_assetsOrShares / 2 == 0 ? 1 : _assetsOrShares / 2, depositor, _sameAsset());

        if (_interest) vm.warp(block.timestamp + 100 days);

        uint256 preview = _useRedeem()
            ? _silo().previewRedeem(amountToUse, assetType)
            : _silo().previewWithdraw(amountToUse, assetType);

        if (!_interest || protectedType) {
            assertEq(preview, amountToUse, "previewWithdraw == assets == shares, when no interest");
        }

        _assertPreviewWithdraw(preview, amountToUse);
    }

    function _assertPreviewWithdraw(uint256 _preview, uint128 _assetsOrShares) internal {
        vm.assume(_preview > 0);
        vm.prank(depositor);

        uint256 results = _useRedeem()
            ? _silo().redeem(_assetsOrShares, depositor, depositor, _collateralType())
            : _silo().withdraw(_assetsOrShares, depositor, depositor, _collateralType());

        assertGt(results, 0, "expect any withdraw amount > 0");

        if (_useRedeem()) assertEq(_preview, results, "preview should give us exact result, NOT more");
        else assertEq(_preview, results, "preview should give us exact result, NOT fewer");
    }
    
    function _useRedeem() internal pure virtual returns (bool) {
        return false;
    }

    function _collateralType() internal pure virtual returns (ISilo.CollateralType) {
        return ISilo.CollateralType.Collateral;
    }

    function _sameAsset() internal pure virtual returns (bool) {
        return false;
    }

    function _silo() private view returns (ISilo) {
        return _sameAsset() ? silo1 : silo0;
    }
}
