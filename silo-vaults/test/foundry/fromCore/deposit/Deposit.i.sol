// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

import {ErrorsLib} from "silo-vaults/contracts/libraries/ErrorsLib.sol";
import {MarketConfig} from "silo-vaults/contracts/libraries/PendingLib.sol";
import {VaultsLittleHelper} from "../_common/VaultsLittleHelper.sol";

/*
    FOUNDRY_PROFILE=vaults_tests forge test --ffi --mc DepositTest -vv
*/
contract DepositTest is VaultsLittleHelper {
    /*
    forge test -vv --ffi --mt test_deposit_revertsZeroAssets
    */
    function test_deposit_revertsZeroAssets() public {
        uint256 _assets;
        address depositor = makeAddr("Depositor");

        vm.expectRevert(ErrorsLib.ZeroShares.selector);
        vault.deposit(_assets, depositor);
    }

    /*
    forge test -vv --ffi --mt test_deposit_totalAssets
    */
    function test_deposit_totalAssets() public {
        _deposit(123, makeAddr("Depositor"));

        assertEq(vault.totalAssets(), 123, "totalAssets match deposit");
    }

    /*
    FOUNDRY_PROFILE=vaults_tests forge test --ffi --mt test_deposit_balanceTracker -vvv
    */
    function test_deposit_balanceTracker() public {
        uint256 length = vault.supplyQueueLength();

        assertGt(length, 1, "supplyQueueLength less than 2");

        IERC4626 market0 = vault.supplyQueue(0);
        IERC4626 market1 = vault.supplyQueue(1);

        uint256 balanceBefore0 = vault.balanceTracker(market0);
        uint256 balanceBefore1 = vault.balanceTracker(market1);

        assertEq(balanceBefore0, 0, "expect balanceBefore0 to be 0");
        assertEq(balanceBefore1, 0, "expect balanceBefore1 to be 0");

        MarketConfig memory config0 = vault.config(market0);

        uint256 depositOverCap = 100;

        uint256 depositAmount = config0.cap + depositOverCap;

        _deposit(depositAmount, makeAddr("Depositor"));

        uint256 balanceAfter0 = vault.balanceTracker(market0);
        uint256 balanceAfter1 = vault.balanceTracker(market1);

        assertEq(balanceAfter0, config0.cap, "balanceAfter0 should be config0.cap");
        assertEq(balanceAfter1, depositOverCap, "balanceAfter1 should be depositOverCap");
    }

    /*
    FOUNDRY_PROFILE=vaults_tests forge test --ffi --mt test_deposit_balanceTracker_MarketReportedWrongSupply -vvv
    */
    function test_deposit_balanceTracker_MarketReportedWrongSupply() public {
        uint256 length = vault.supplyQueueLength();

        assertGe(length, 2, "supplyQueueLength less than 2");

        IERC4626 market0 = vault.supplyQueue(0);
        IERC4626 market1 = vault.supplyQueue(1);

        uint256 balanceBefore0 = vault.balanceTracker(market0);

        assertEq(balanceBefore0, 0, "expect balanceBefore0 to be 0");

        MarketConfig memory config0 = vault.config(market0);

        address depositor = makeAddr("Depositor");
        uint256 depositBelowCap = 100;

        uint256 depositAmount = config0.cap - depositBelowCap;

        _deposit(depositAmount, depositor);

        uint256 balanceAfter0 = vault.balanceTracker(market0);

        assertEq(balanceAfter0, depositAmount, "invalid balanceAfter0");

        uint256 sharesBalance = market0.balanceOf(address(vault));
        uint256 currentPreviewRedeem = market0.previewRedeem(sharesBalance);

        bytes memory data = abi.encodeWithSelector(IERC4626.previewRedeem.selector, sharesBalance);

        // vault hacked and started to report wrong supply, based on which we can deploy all tokens again
        vm.mockCall(address(market0), data, abi.encode(0));
        vm.expectCall(address(market0), data);

        _deposit(depositBelowCap * 2, depositor);

        uint256 balanceAfter1 = vault.balanceTracker(market1);

        assertEq(balanceAfter0 + depositBelowCap, vault.balanceTracker(market0), "expect deposit to market0 up to internal CAP");
        assertEq(balanceAfter1, depositBelowCap, "expect deposit to market1");
    }
}
