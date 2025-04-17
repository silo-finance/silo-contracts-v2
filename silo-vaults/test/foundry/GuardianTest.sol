// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

import {PendingUint192, MarketConfig, PendingAddress} from "../../contracts/libraries/PendingLib.sol";
import {ErrorsLib} from "../../contracts/libraries/ErrorsLib.sol";
import {EventsLib} from "../../contracts/libraries/EventsLib.sol";
import {ConstantsLib} from "../../contracts/libraries/ConstantsLib.sol";

import {IntegrationTest} from "./helpers/IntegrationTest.sol";
import {TIMELOCK, CAP} from "./helpers/BaseTest.sol";

/*
 FOUNDRY_PROFILE=vaults_tests forge test --ffi --mc GuardianTest -vvv
*/
contract GuardianTest is IntegrationTest {
    function setUp() public override {
        super.setUp();

        _setGuardian(GUARDIAN);
    }

    function testSubmitGuardianNotOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        vault.submitGuardian(GUARDIAN);
    }

    function testSubmitGuardianAlreadySet() public {
        vm.prank(OWNER);
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        vault.submitGuardian(GUARDIAN);
    }

    function testGuardianRevokePendingTimelockDecreased(uint256 timelock, uint256 elapsed) public {
        timelock = bound(timelock, ConstantsLib.MIN_TIMELOCK, TIMELOCK - 1);
        elapsed = bound(elapsed, 0, TIMELOCK - 1);

        vm.prank(OWNER);
        vault.submitTimelock(timelock);

        vm.warp(block.timestamp + elapsed);

        vm.expectEmit(address(vault));
        emit EventsLib.RevokePendingTimelock(GUARDIAN);
        vm.prank(GUARDIAN);
        vault.revokePendingTimelock();

        uint256 newTimelock = vault.timelock();
        PendingUint192 memory pendingTimelock = vault.pendingTimelock();

        assertEq(newTimelock, TIMELOCK, "newTimelock");
        assertEq(pendingTimelock.value, 0, "pendingTimelock.value");
        assertEq(pendingTimelock.validAt, 0, "pendingTimelock.validAt");
    }

    function testOwnerRevokePendingTimelockDecreased(uint256 timelock, uint256 elapsed) public {
        timelock = bound(timelock, ConstantsLib.MIN_TIMELOCK, TIMELOCK - 1);
        elapsed = bound(elapsed, 0, TIMELOCK - 1);

        vm.prank(OWNER);
        vault.submitTimelock(timelock);

        vm.warp(block.timestamp + elapsed);

        vm.expectEmit();
        emit EventsLib.RevokePendingTimelock(OWNER);
        vm.prank(OWNER);
        vault.revokePendingTimelock();

        uint256 newTimelock = vault.timelock();
        PendingUint192 memory pendingTimelock = vault.pendingTimelock();

        assertEq(newTimelock, TIMELOCK, "newTimelock");
        assertEq(pendingTimelock.value, 0, "value");
        assertEq(pendingTimelock.validAt, 0, "validAt");
    }

    function testGuardianRevokePendingCapIncreased(uint256 seed, uint256 cap, uint256 elapsed) public {
        IERC4626 market = _randomMarket(seed);
        elapsed = bound(elapsed, 0, TIMELOCK - 1);
        cap = bound(cap, 1, type(uint184).max);

        vm.prank(OWNER);
        vault.submitCap(market, cap);

        vm.warp(block.timestamp + elapsed);

        vm.expectEmit(address(vault));
        emit EventsLib.RevokePendingCap(GUARDIAN, market);
        vm.prank(GUARDIAN);
        vault.revokePendingCap(market);

        MarketConfig memory marketConfig = vault.config(market);
        PendingUint192 memory pendingCap = vault.pendingCap(market);

        assertEq(marketConfig.cap, 0, "marketConfig.cap");
        assertEq(marketConfig.enabled, false, "marketConfig.enabled");
        assertEq(marketConfig.removableAt, 0, "marketConfig.removableAt");
        assertEq(pendingCap.value, 0, "pendingCap.value");
        assertEq(pendingCap.validAt, 0, "pendingCap.validAt");
    }

    function testGuardianRevokePendingGuardian(uint256 elapsed) public {
        elapsed = bound(elapsed, 0, TIMELOCK - 1);

        address guardian = makeAddr("Guardian2");

        vm.prank(OWNER);
        vault.submitGuardian(guardian);

        vm.warp(block.timestamp + elapsed);

        vm.expectEmit(address(vault));
        emit EventsLib.RevokePendingGuardian(GUARDIAN);
        vm.prank(GUARDIAN);
        vault.revokePendingGuardian();

        address newGuardian = vault.guardian();
        PendingAddress memory pendingGuardian = vault.pendingGuardian();

        assertEq(newGuardian, GUARDIAN, "newGuardian");
        assertEq(pendingGuardian.value, address(0), "pendingGuardian.value");
        assertEq(pendingGuardian.validAt, 0, "pendingGuardian.validAt");
    }

    function testRevokePendingMarketRemoval(uint256 elapsed) public {
        elapsed = bound(elapsed, 0, TIMELOCK - 1);

        IERC4626 market = allMarkets[0];

        _setCap(market, CAP);
        _setCap(market, 0);

        vm.prank(CURATOR);
        vault.submitMarketRemoval(allMarkets[0]);

        vm.warp(block.timestamp + elapsed);

        vm.expectEmit(address(vault));
        emit EventsLib.RevokePendingMarketRemoval(GUARDIAN, market);
        vm.prank(GUARDIAN);
        vault.revokePendingMarketRemoval(market);

        MarketConfig memory marketConfig = vault.config(market);

        assertEq(marketConfig.cap, 0, "marketConfig.cap");
        assertEq(marketConfig.enabled, true, "marketConfig.enabled");
        assertEq(marketConfig.removableAt, 0, "marketConfig.removableAt");
    }
}
