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
            ? silo0.previewRedeem(amountToUse, assetType)
            : silo0.previewWithdraw(amountToUse, assetType);

        // first deposit AFTER preview
        _deposit(_assetsOrShares, depositor, assetType);

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

        _deposit(uint256(_assetsOrShares) * 2 - (_assetsOrShares % 2), depositor, assetType);

        uint256 preview = _useRedeem()
            ? silo0.previewRedeem(amountToUse, assetType)
            : silo0.previewWithdraw(amountToUse, assetType);

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
        uint128 amountToUse = _partial ? uint128(uint256(_assetsOrShares) * 37 / 100) : _assetsOrShares;
        vm.assume(amountToUse > 0);

        ISilo.CollateralType assetType = _collateralType();
        bool protectedType = assetType == ISilo.CollateralType.Protected;

        // we need interest on silo0, where we doing deposit
        _depositForBorrow(uint256(_assetsOrShares) * 2, borrower); // deposit collateral for silo1
        _deposit(uint256(_assetsOrShares) * 2 + (_assetsOrShares % 2), depositor); // deposit for silo0, for borrow

        if (protectedType) {
            _deposit(uint256(_assetsOrShares) * 2 + (_assetsOrShares % 2), depositor, assetType);
        }

        vm.prank(borrower);
        silo0.borrow(_assetsOrShares / 2 == 0 ? 1 : _assetsOrShares / 2, borrower, borrower);

        if (_interest) vm.warp(block.timestamp + 100 days);

        uint256 preview = _useRedeem()
            ? silo0.previewRedeem(amountToUse, assetType)
            : silo0.previewWithdraw(amountToUse, assetType);

        if (!_interest || protectedType) {
            assertEq(preview, amountToUse, "previewWithdraw == assets == shares, when no interest");
        }

        _assertPreviewWithdraw(preview, amountToUse);
    }

    function _assertPreviewWithdraw(uint256 _preview, uint128 _assetsOrShares) internal {
        vm.assume(_preview > 0);
        vm.prank(depositor);

        uint256 results = _useRedeem()
            ? silo0.redeem(_assetsOrShares, depositor, depositor, _collateralType())
            : silo0.withdraw(_assetsOrShares, depositor, depositor, _collateralType());

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
}
