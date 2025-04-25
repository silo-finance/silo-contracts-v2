// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";
import {Ownable} from "openzeppelin5/access/Ownable2Step.sol";

import {MarketAllocation} from "../../contracts/interfaces/ISiloVault.sol";
import {ErrorsLib} from "../../contracts/libraries/ErrorsLib.sol";
import {EventsLib} from "../../contracts/libraries/EventsLib.sol";

import {IntegrationTest} from "./helpers/IntegrationTest.sol";
import {CAP} from "./helpers/BaseTest.sol";

/*
FOUNDRY_PROFILE=vaults_tests forge test --ffi --mc RoleTest -vvv
*/
contract RoleTest is IntegrationTest {
    function testSetCurator() public {
        address newCurator = makeAddr("Curator2");

        vm.expectEmit();
        emit EventsLib.SetCurator(newCurator);
        vm.prank(OWNER);
        vault.setCurator(newCurator);

        assertEq(vault.curator(), newCurator, "curator");
    }

    function testSetCuratorShouldRevertAlreadySet() public {
        vm.prank(OWNER);
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        vault.setCurator(CURATOR);
    }

    function testSetAllocator() public {
        address newAllocator = makeAddr("Allocator2");

        vm.expectEmit();
        emit EventsLib.SetIsAllocator(newAllocator, true);
        vm.prank(OWNER);
        vault.setIsAllocator(newAllocator, true);

        assertTrue(vault.isAllocator(newAllocator), "isAllocator");
    }

    function testUnsetAllocator() public {
        vm.expectEmit();
        emit EventsLib.SetIsAllocator(ALLOCATOR, false);
        vm.prank(OWNER);
        vault.setIsAllocator(ALLOCATOR, false);

        assertFalse(vault.isAllocator(ALLOCATOR), "isAllocator");
    }

    function testSetAllocatorShouldRevertAlreadySet() public {
        vm.prank(OWNER);
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        vault.setIsAllocator(ALLOCATOR, true);
    }

    function testOwnerFunctionsShouldRevertWhenNotOwner(address caller) public {
        vm.assume(caller != vault.owner());

        vm.startPrank(caller);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(caller)));
        vault.setCurator(caller);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(caller)));
        vault.setIsAllocator(caller, true);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(caller)));
        vault.submitTimelock(1);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(caller)));
        vault.setFee(1);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(caller)));
        vault.submitGuardian(address(1));

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(caller)));
        vault.setFeeRecipient(caller);

        vm.stopPrank();
    }

    function testCuratorFunctionsShouldRevertWhenNotCuratorRole(address caller) public {
        vm.assume(caller != vault.owner() && caller != vault.curator());

        vm.startPrank(caller);

        vm.expectRevert(ErrorsLib.NotCuratorRole.selector);
        vault.submitCap(allMarkets[0], CAP);

        vm.stopPrank();
    }

    function testCuratorOrGuardianFunctionsShouldRevertWhenNotCuratorOrGuardianRole(address caller, IERC4626 market) public {
        vm.assume(caller != vault.owner() && caller != vault.curator() && caller != vault.guardian());

        vm.startPrank(caller);

        vm.expectRevert(ErrorsLib.NotCuratorNorGuardianRole.selector);
        vault.revokePendingCap(market);

        vm.expectRevert(ErrorsLib.NotCuratorNorGuardianRole.selector);
        vault.revokePendingMarketRemoval(market);

        vm.stopPrank();
    }

    function testGuardianFunctionsShouldRevertWhenNotGuardianRole(address caller) public {
        vm.assume(caller != vault.owner() && caller != vault.guardian());

        vm.startPrank(caller);

        vm.expectRevert(ErrorsLib.NotGuardianRole.selector);
        vault.revokePendingTimelock();

        vm.expectRevert(ErrorsLib.NotGuardianRole.selector);
        vault.revokePendingGuardian();

        vm.stopPrank();
    }

    function testAllocatorFunctionsShouldRevertWhenNotAllocatorRole(address caller) public {
        vm.assume(!vault.isAllocator(caller) && caller != vault.owner() && caller != vault.curator());

        vm.startPrank(caller);

        IERC4626[] memory supplyQueue;
        MarketAllocation[] memory allocation;
        uint256[] memory withdrawQueueFromRanks;

        vm.expectRevert(ErrorsLib.NotAllocatorRole.selector);
        vault.setSupplyQueue(supplyQueue);

        vm.expectRevert(ErrorsLib.NotAllocatorRole.selector);
        vault.updateWithdrawQueue(withdrawQueueFromRanks);

        vm.expectRevert(ErrorsLib.NotAllocatorRole.selector);
        vault.reallocate(allocation);

        vm.stopPrank();
    }

    function testCuratorOrOwnerShouldTriggerCuratorFunctions() public {
        vm.prank(OWNER);
        vault.submitCap(allMarkets[0], CAP);

        vm.prank(CURATOR);
        vault.submitCap(allMarkets[1], CAP);
    }

    function testAllocatorOrCuratorOrOwnerShouldTriggerAllocatorFunctions() public {
        IERC4626[] memory supplyQueue = new IERC4626[](1);
        supplyQueue[0] = idleMarket;

        uint256[] memory withdrawQueueFromRanks = new uint256[](1);
        withdrawQueueFromRanks[0] = 0;

        MarketAllocation[] memory allocation;

        vm.startPrank(OWNER);
        vault.setSupplyQueue(supplyQueue);
        vault.updateWithdrawQueue(withdrawQueueFromRanks);
        vault.reallocate(allocation);

        vm.startPrank(CURATOR);
        vault.setSupplyQueue(supplyQueue);
        vault.updateWithdrawQueue(withdrawQueueFromRanks);
        vault.reallocate(allocation);

        vm.startPrank(ALLOCATOR);
        vault.setSupplyQueue(supplyQueue);
        vault.updateWithdrawQueue(withdrawQueueFromRanks);
        vault.reallocate(allocation);
        vm.stopPrank();
    }
}
