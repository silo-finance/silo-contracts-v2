// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

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
    /// forge-config: core.fuzz.runs = 10000
    function test_previewWithdraw_noInterestNoDebt_fuzz(uint128 _assetsOrShares, bool _doRedeem, bool _partial) public {
        uint128 amountToUse = _partial ? uint128(uint256(_assetsOrShares) * 37 / 100) : _assetsOrShares;
        vm.assume(amountToUse > 0);

        // preview before deposit creation
        uint256 preview = _doRedeem ? silo0.previewRedeem(amountToUse) : silo0.previewWithdraw(amountToUse);

        // first deposit AFTER preview
        _deposit(_assetsOrShares, depositor);

        assertEq(preview, amountToUse, "previewWithdraw == assets == shares, when no interest");

        _assertPreviewWithdraw(preview, amountToUse, _doRedeem);
    }

    /*
    forge test -vv --ffi --mt test_previewWithdraw_noDebt_fuzz
    */
    /// forge-config: core.fuzz.runs = 10000
    function test_previewWithdraw_noDebt_fuzz(uint128 _assetsOrShares, bool _doRedeem, bool _partial) public {
        uint128 amountToUse = _partial ? uint128(uint256(_assetsOrShares) * 37 / 100) : _assetsOrShares;
        vm.assume(amountToUse > 0);

        _deposit(uint256(_assetsOrShares) * 2 - (_assetsOrShares % 2), depositor);

        uint256 preview = _doRedeem ? silo0.previewRedeem(amountToUse) : silo0.previewWithdraw(amountToUse);

        assertEq(preview, amountToUse, "previewWithdraw == assets == shares, when no interest");

        _assertPreviewWithdraw(preview, amountToUse, _doRedeem);
    }

    /*
    forge test -vv --ffi --mt test_previewWithdraw_debt_fuzz
    */
    /// forge-config: core.fuzz.runs = 10000
    function test_previewWithdraw_debt_fuzz(uint128 _assetsOrShares, bool _doRedeem, bool _interest, bool _partial) public {
        uint128 amountToUse = _partial ? uint128(uint256(_assetsOrShares) * 37 / 100) : _assetsOrShares;
        vm.assume(amountToUse > 0);

        // we need interest on silo0, where we doing deposit
        _depositForBorrow(uint256(_assetsOrShares) * 2, borrower); // deposit collateral for silo1
        _deposit(uint256(_assetsOrShares) * 2 + (_assetsOrShares % 2), depositor); // deposit for silo0

        vm.prank(borrower);
        silo0.borrow(_assetsOrShares / 2 == 0 ? 1 : _assetsOrShares / 2, borrower, borrower);

        if (_interest) vm.warp(block.timestamp + 100 days);

        uint256 preview = _doRedeem ? silo0.previewRedeem(amountToUse) : silo0.previewWithdraw(amountToUse);

        if (!_interest) assertEq(preview, amountToUse, "previewWithdraw == assets == shares, when no interest");

        _assertPreviewWithdraw(preview, amountToUse, _doRedeem);
    }

    function _assertPreviewWithdraw(uint256 _preview, uint128 _assetsOrShares, bool _useRedeem) internal {
        vm.assume(_preview > 0);
        vm.prank(depositor);

        uint256 results = _useRedeem
            ? silo0.redeem(_assetsOrShares, depositor, depositor)
            : silo0.withdraw(_assetsOrShares, depositor, depositor);

        assertGt(results, 0, "expect any withdraw amount > 0");

        if (_useRedeem) assertEq(_preview, results, "preview should give us exact result, NOT more");
        else assertEq(_preview, results, "preview should give us exact result, NOT fewer");
    }
}
