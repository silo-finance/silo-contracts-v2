// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

import {PendingUint192, PendingAddress} from "../../../contracts/libraries/PendingLib.sol";

import {BaseTest} from "./BaseTest.sol";

contract IntegrationTest is BaseTest {
    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(OWNER);
        vault.setCurator(CURATOR);
        vault.setIsAllocator(ALLOCATOR, true);
        vault.setFeeRecipient(FEE_RECIPIENT);
        vm.stopPrank();

        _setCap(idleMarket, type(uint184).max);
    }

    function _idle() internal view returns (uint256) {
        return _expectedSupplyAssets(idleMarket, address(vault));
    }

    function _setTimelock(uint256 newTimelock) internal {
        uint256 timelock = vault.timelock();
        if (newTimelock == timelock) return;

        // block.timestamp defaults to 1 which may lead to an unrealistic state: block.timestamp < timelock.
        if (block.timestamp < timelock) vm.warp(block.timestamp + timelock);

        PendingUint192 memory pendingTimelock = vault.pendingTimelock();
        if (pendingTimelock.validAt == 0 || newTimelock != pendingTimelock.value) {
            vm.prank(OWNER);
            vault.submitTimelock(newTimelock);
        }

        if (newTimelock > timelock) return;

        vm.warp(block.timestamp + timelock);

        vault.acceptTimelock();

        assertEq(vault.timelock(), newTimelock, "_setTimelock");
    }

    function _setGuardian(address newGuardian) internal {
        address guardian = vault.guardian();
        if (newGuardian == guardian) return;

        PendingAddress memory pendingGuardian = vault.pendingGuardian();
        if (pendingGuardian.validAt == 0 || newGuardian != pendingGuardian.value) {
            vm.prank(OWNER);
            vault.submitGuardian(newGuardian);
        }

        if (guardian == address(0)) return;

        vm.warp(block.timestamp + vault.timelock());

        vault.acceptGuardian();

        assertEq(vault.guardian(), newGuardian, "_setGuardian");
    }

    function _setFee(uint256 newFee) internal {
        uint256 fee = vault.fee();
        if (newFee == fee) return;

        vm.prank(OWNER);
        vault.setFee(newFee);

        assertEq(vault.fee(), newFee, "_setFee");
    }

    function _setCap(IERC4626 market, uint256 newCap) internal {
        uint256 cap = vault.config(market).cap;
        bool isEnabled = vault.config(market).enabled;
        if (newCap == cap) return;

        PendingUint192 memory pendingCap = vault.pendingCap(market);
        if (pendingCap.validAt == 0 || newCap != pendingCap.value) {
            vm.prank(CURATOR);
            vault.submitCap(market, newCap);
        }

        if (newCap < cap) return;

        vm.warp(block.timestamp + vault.timelock());

        vault.acceptCap(market);

        assertEq(vault.config(market).cap, newCap, "_setCap");

        if (newCap > 0) {
            if (!isEnabled) {
                IERC4626[] memory newSupplyQueue = new IERC4626[](vault.supplyQueueLength() + 1);
                for (uint256 k; k < vault.supplyQueueLength(); k++) {
                    newSupplyQueue[k] = vault.supplyQueue(k);
                }
                newSupplyQueue[vault.supplyQueueLength()] = market;
                vm.prank(ALLOCATOR);
                vault.setSupplyQueue(newSupplyQueue);
            }
        }
    }

    function _setCapSimple(IERC4626 market, uint256 newCap) internal {
        uint256 cap = vault.config(market).cap;

        vm.prank(CURATOR);
        vault.submitCap(market, newCap);

        if (newCap < cap) return;

        vm.warp(block.timestamp + vault.timelock());

        vault.acceptCap(market);
    }

    function _setOneMarketToSupplyQueue(IERC4626 market) internal {
        IERC4626[] memory supplyQueue = new IERC4626[](1);
        supplyQueue[0] = market;

        vm.prank(ALLOCATOR);
        vault.setSupplyQueue(supplyQueue);
    }

    function _sortSupplyQueueIdleLast() internal {
        IERC4626[] memory supplyQueue = new IERC4626[](vault.supplyQueueLength());

        uint256 supplyIndex;
        for (uint256 i; i < supplyQueue.length; ++i) {
            IERC4626 market = vault.supplyQueue(i);
            if (address(market) == address(idleMarket)) continue;

            supplyQueue[supplyIndex] = market;
            ++supplyIndex;
        }

        supplyQueue[supplyIndex] = idleMarket;
        ++supplyIndex;

        assembly {
            mstore(supplyQueue, supplyIndex)
        }

        vm.prank(ALLOCATOR);
        vault.setSupplyQueue(supplyQueue);
    }
}
