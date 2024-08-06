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
        uint256 amountIn = _partial ? uint256(_assetsOrShares) * 37 / 100 : _assetsOrShares;
        vm.assume(amountIn > 0);

        ISilo.CollateralType assetType = _collateralType();

        _depositForTestPreview(_assetsOrShares);

        uint256 preview = _getPreview(amountIn);

        assertEq(preview, amountIn, "previewWithdraw == assets == shares, when no interest");

        _assertPreviewWithdraw(preview, amountIn);
    }

    /*
    forge test -vv --ffi --mt test_previewWithdraw_debt_fuzz
    same asset: we check preview on same silo
    two assets: we need to borrow on silo0 in addition
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

        _depositForTestPreview(_assetsOrShares);

        _createSiloUsage();

        if (_interest) vm.warp(block.timestamp + 200 days);

        uint256 preview = _getPreview(amountToUse);

        if (!_interest || protectedType) {
            assertEq(preview, amountToUse, "previewWithdraw == assets == shares, when no interest");
        }

        _assertPreviewWithdraw(preview, amountToUse);
    }

    /*
    forge test -vv --ffi --mt test_previewWithdraw_random_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 10000
    function test_previewWithdraw_random_fuzz(uint64 _assetsOrShares, bool _interest) public {
        vm.assume(_assetsOrShares > 0);

        ISilo.CollateralType assetType = _collateralType();
        bool protectedType = assetType == ISilo.CollateralType.Protected;

        _depositForTestPreview(_assetsOrShares);

        _createSiloUsage();

        if (_interest) vm.warp(block.timestamp + 500 days);

        uint256 preview = _getPreview(_assetsOrShares);

        if (!_interest || protectedType) {
            assertEq(preview, _assetsOrShares, "previewWithdraw == assets == shares, when no interest");
        }

        _assertPreviewWithdraw(preview, _assetsOrShares);
    }

    /*
    forge test -vv --ffi --mt test_previewWithdraw_min_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 10000
    function test_previewWithdraw_min_fuzz(uint64 _assetsOrShares, bool _interest) public {
        vm.assume(_assetsOrShares > 0);

        ISilo.CollateralType assetType = _collateralType();
        bool protectedType = assetType == ISilo.CollateralType.Protected;

        _depositForTestPreview(_assetsOrShares);

        _createSiloUsage();

        if (_interest) vm.warp(block.timestamp + 500 days);

        uint256 minInput = _useRedeem() ? 1 : silo1.convertToAssets(1);
        uint256 minPreview = _getPreview(minInput);

        if (!_interest || protectedType) {
            assertEq(minPreview, minInput, "previewWithdraw == assets == shares, when no interest");
        }

        _assertPreviewWithdraw(minPreview, minInput);
    }

    /*
    forge test -vv --ffi --mt test_previewWithdraw_max_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 10000
    function test_previewWithdraw_max_fuzz(uint64 _assetsOrShares, bool _interest) public {
        vm.assume(_assetsOrShares > 0);

        ISilo.CollateralType assetType = _collateralType();
        bool protectedType = assetType == ISilo.CollateralType.Protected;

        _depositForTestPreview(_assetsOrShares);

        _createSiloUsage();

        if (_interest) vm.warp(block.timestamp + 500 days);

        uint256 maxInput = _useRedeem()
            ? _getShareToken().balanceOf(depositor)
            : silo1.maxWithdraw(depositor, _collateralType());

        uint256 maxPreview = _getPreview(maxInput);

        if (!_interest || protectedType) {
            assertEq(maxPreview, maxInput, "previewWithdraw == assets == shares, when no interest");
        }

        _assertPreviewWithdraw(maxPreview, maxInput);
    }

    function _depositForTestPreview(uint256 _assetsOrShares) internal {
        _depositCollateral({
            _assets: _assetsOrShares,
            _depositor: depositor,
            _toSilo1: true,
            _collateralType: _collateralType()
        });
    }

    function _createSiloUsage() internal {
        _depositForBorrow(type(uint128).max, depositor);

        address otherDepositor = makeAddr("otherDepositor");
        _depositCollateral(type(uint128).max, otherDepositor, _sameAsset(), _collateralType());
        _borrow(type(uint64).max, otherDepositor, _sameAsset());
    }

    function _assertPreviewWithdraw(uint256 _preview, uint256 _assetsOrShares) internal {
        vm.assume(_preview > 0);
        vm.prank(depositor);

        uint256 results = _useRedeem()
            ? silo1.redeem(_assetsOrShares, depositor, depositor, _collateralType())
            : silo1.withdraw(_assetsOrShares, depositor, depositor, _collateralType());

        assertGt(results, 0, "expect any withdraw amount > 0");

        if (_useRedeem()) assertEq(_preview, results, "preview should give us exact result, NOT more");
        else assertEq(_preview, results, "preview should give us exact result, NOT fewer");
    }

    function _getShareToken() internal view virtual returns (IShareToken shareToken) {
        (address protectedShareToken, address collateralShareToken, ) = siloConfig.getShareTokens(address(silo1));
        shareToken = _collateralType() == ISilo.CollateralType.Collateral
            ? IShareToken(collateralShareToken)
            : IShareToken(protectedShareToken);
    }

    function _getPreview(uint256 _amountToUse) internal view virtual returns (uint256 preview) {
        preview = _useRedeem()
            ? silo1.previewRedeem(_amountToUse, _collateralType())
            : silo1.previewWithdraw(_amountToUse, _collateralType());
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
}
