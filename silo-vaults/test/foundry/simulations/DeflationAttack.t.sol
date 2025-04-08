// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

import {ErrorsLib} from "silo-vaults/contracts/libraries/ErrorsLib.sol";
import {IntegrationTest} from "../helpers/IntegrationTest.sol";

/*
 FOUNDRY_PROFILE=vaults-tests forge test --ffi --mc MarketTest -vvv
*/
contract DeflationAttackTest is IntegrationTest {
    /*
    FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt test_deflationAttack -vvv
    */
    function test_deflationAttack_noMarketRoundingDown() public {
        _setCap(allMarkets[0], 1000e18);
        _sortSupplyQueueIdleLast();

        uint256 assets = 1;
        address depositor = makeAddr("depositor");
        
        vm.prank(depositor);
        uint256 shares = vault.deposit(assets, depositor);
        uint256 lastTotalAssets = vault.lastTotalAssets();
        uint256 totalAssets = vault.totalAssets();
        uint256 depositorShares = vault.balanceOf(depositor);

        emit log_named_uint("shares", shares); // 1000_000
        emit log_named_uint("lastTotalAssets", lastTotalAssets); // 1
        emit log_named_uint("totalAssets", totalAssets); // 1
        emit log_named_uint("depositorShares", depositorShares); // 1000_000

        vm.prank(depositor);
        shares = vault.deposit(assets, depositor);
        lastTotalAssets = vault.lastTotalAssets();
        totalAssets = vault.totalAssets();
        depositorShares = vault.balanceOf(depositor);

        emit log_named_uint("shares after", shares); // 1000_000
        emit log_named_uint("lastTotalAssets after", lastTotalAssets); // 2
        emit log_named_uint("totalAssets", totalAssets); // 2
        emit log_named_uint("depositorShares", depositorShares); // 2000_000
    }

    /*
     FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt test_deflationAttack_marketRoundingDown -vvv
     */
    function test_deflationAttack_marketRoundingDown_fewSteps() public {
        _setCap(allMarkets[0], 1000e18);
        _sortSupplyQueueIdleLast();

        uint256 assets = 1;
        address depositor = makeAddr("depositor");

        bytes memory data = abi.encodeWithSelector(IERC4626.deposit.selector, assets, address(vault));

        vm.mockCall(address(allMarkets[0]), data, abi.encode(0));
        vm.expectCall(address(allMarkets[0]), data);

        vm.prank(depositor);
        uint256 shares = vault.deposit(assets, depositor);
        uint256 lastTotalAssets = vault.lastTotalAssets();
        uint256 totalAssets = vault.totalAssets();
        uint256 depositorShares = vault.balanceOf(depositor);

        emit log_named_uint("shares", shares); // 1000_000
        emit log_named_uint("lastTotalAssets", lastTotalAssets); // 1
        emit log_named_uint("totalAssets", totalAssets); // 0
        emit log_named_uint("depositorShares", depositorShares); // 1000_000

        vm.prank(depositor);
        shares = vault.deposit(assets, depositor);
        lastTotalAssets = vault.lastTotalAssets();
        totalAssets = vault.totalAssets();
        depositorShares = vault.balanceOf(depositor);

        emit log_named_uint("shares after", shares); // 2000_000
        emit log_named_uint("lastTotalAssets after", lastTotalAssets); // 1
        emit log_named_uint("totalAssets", totalAssets); // 0
        emit log_named_uint("depositorShares", depositorShares); // 3000_000

        vm.prank(depositor);
        shares = vault.deposit(assets, depositor);
        lastTotalAssets = vault.lastTotalAssets();
        totalAssets = vault.totalAssets();
        depositorShares = vault.balanceOf(depositor);

        emit log_named_uint("shares after", shares); // 4_000_000
        emit log_named_uint("lastTotalAssets after", lastTotalAssets); // 1
        emit log_named_uint("totalAssets", totalAssets); // 0
        emit log_named_uint("depositorShares", depositorShares); // 7_000_000
    }

    /*
     FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt test_deflationAttack_marketRoundingDown_withDepositor -vvv
     */
    function test_deflationAttack_marketRoundingDown_withDepositor() public {
        _setCap(allMarkets[0], 1000e18);
        _sortSupplyQueueIdleLast();

        uint256 oneWei = 1;
        address attacker = makeAddr("attacker");

        bytes memory data = abi.encodeWithSelector(IERC4626.deposit.selector, oneWei, address(vault));

        for (uint256 i; i < 100; i++) {
            vm.mockCall(address(allMarkets[0]), data, abi.encode(0));
            vm.expectCall(address(allMarkets[0]), data);

            vm.prank(attacker);
            vault.deposit(oneWei, attacker);
        }

        uint256 lastTotalAssets = vault.lastTotalAssets();
        uint256 totalAssets = vault.totalAssets();
        uint256 attackerShares = vault.balanceOf(attacker);

        emit log_named_uint("lastTotalAssets", lastTotalAssets); // 1
        emit log_named_uint("totalAssets", totalAssets); // 0 
        emit log_named_uint("attackerShares", attackerShares); // 1267650600228229401496703205375000000

        // regular depositor
        uint256 depositAmount = 1000_000e6;
        address depositor = makeAddr("depositor");

        vm.prank(depositor);
        vault.deposit(depositAmount, depositor);

        lastTotalAssets = vault.lastTotalAssets();
        totalAssets = vault.totalAssets();
        uint256 depositorShares = vault.balanceOf(depositor);

        emit log_named_uint("lastTotalAssets", lastTotalAssets); // 1000000000000
        emit log_named_uint("totalAssets", totalAssets); // 1000000000000
        emit log_named_uint("depositorShares", depositorShares); // 1267650600228229401496703205376000000000000000000

        // withdraw all
        vm.prank(depositor);
        uint256 receivedAssets = vault.redeem(depositorShares, depositor, depositor);

        emit log_named_uint("receivedAssets", receivedAssets); // 1000_000e6 (the same as deposited)

        uint256 totalSupply = vault.totalSupply();
        lastTotalAssets = vault.lastTotalAssets();
        totalAssets = vault.totalAssets();

        emit log_named_uint("totalSupply", totalSupply); // 1267650600228229401496703205375000000
        emit log_named_uint("lastTotalAssets", lastTotalAssets); // 0
        emit log_named_uint("totalAssets", totalAssets); // 0
    }

    /*
     FOUNDRY_PROFILE=vaults-tests \
        forge test --ffi --mt test_deflationAttack_marketRoundingDown_attackerWithdrawFirst -vvv
     */
    function test_deflationAttack_marketRoundingDown_attackerWithdrawFirst() public {
        _sortSupplyQueueOnlyIdle();

        uint256 oneWei = 1;
        address attacker = makeAddr("attacker");

        bytes memory data = abi.encodeWithSelector(IERC4626.deposit.selector, oneWei, address(vault));

        for (uint256 i; i < 100; i++) {
            vm.mockCall(address(idleMarket), data, abi.encode(0));
            vm.expectCall(address(idleMarket), data);

            vm.prank(attacker);
            vault.deposit(oneWei, attacker);
        }

        // regular depositor
        uint256 depositAmount = 1000_000e6;
        address depositor = makeAddr("depositor");

        vm.prank(depositor);
        vault.deposit(depositAmount, depositor);

        // withdraw all attacker
        uint256 attackerShares = vault.balanceOf(attacker);

        vm.expectRevert();
        vm.prank(attacker);
        uint256 receivedAssets = vault.redeem(attackerShares, attacker, attacker);
    }

    /*
     FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt test_deflationAttack_DOS -vvv
     */
    function test_deflationAttack_DOS() public {
        _setCap(allMarkets[0], 1000e18);
        _sortSupplyQueueIdleLast();
 
        uint256 oneWei = 1;
        address attacker = makeAddr("attacker");

        bytes memory data = abi.encodeWithSelector(IERC4626.deposit.selector, oneWei, address(vault));

        vm.mockCall(address(allMarkets[0]), data, abi.encode(0));

        for (uint256 i; i < 236; i++) {
            vm.prank(attacker);
            vault.deposit(oneWei, attacker);
        }

        uint256 depositAmount = 100e6;
        address depositor = makeAddr("depositor");

        // [FAIL: panic: arithmetic underflow or overflow (0x11)]
        vm.expectRevert();
        vm.prank(depositor);
        vault.deposit(depositAmount, depositor);
    }
}
