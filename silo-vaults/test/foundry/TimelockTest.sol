// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";
import {Ownable} from "openzeppelin5/access/Ownable2Step.sol";

import {PendingUint192, MarketConfig, PendingAddress} from "../../contracts/libraries/PendingLib.sol";
import {ErrorsLib} from "../../contracts/libraries/ErrorsLib.sol";
import {EventsLib} from "../../contracts/libraries/EventsLib.sol";
import {ConstantsLib} from "../../contracts/libraries/ConstantsLib.sol";

import {IntegrationTest} from "./helpers/IntegrationTest.sol";
import {TIMELOCK, CAP} from "./helpers/BaseTest.sol";

uint256 constant FEE = 0.1 ether; // 10%

/*
 FOUNDRY_PROFILE=vaults_tests forge test --ffi --mc TimelockTest -vvv
*/
contract TimelockTest is IntegrationTest {
    function setUp() public override {
        super.setUp();

        _setFee(FEE);
        _setGuardian(GUARDIAN);

        _setCap(allMarkets[0], CAP);
    }

    function testSubmitTimelockIncreased(uint256 timelock) public {
        timelock = bound(timelock, TIMELOCK + 1, ConstantsLib.MAX_TIMELOCK);

        vm.expectEmit(address(vault));
        emit EventsLib.SetTimelock(OWNER, timelock);
        vm.prank(OWNER);
        vault.submitTimelock(timelock);

        uint256 newTimelock = vault.timelock();
        PendingUint192 memory pendingTimelock = vault.pendingTimelock();

        assertEq(newTimelock, timelock, "newTimelock");
        assertEq(pendingTimelock.value, 0, "pendingTimelock.value");
        assertEq(pendingTimelock.validAt, 0, "pendingTimelock.validAt");
    }

    function testSubmitTimelockDecreased(uint256 timelock) public {
        timelock = bound(timelock, ConstantsLib.MIN_TIMELOCK, TIMELOCK - 1);

        vm.expectEmit();
        emit EventsLib.SubmitTimelock(timelock);
        vm.prank(OWNER);
        vault.submitTimelock(timelock);

        uint256 newTimelock = vault.timelock();
        PendingUint192 memory pendingTimelock = vault.pendingTimelock();

        assertEq(newTimelock, TIMELOCK, "newTimelock");
        assertEq(pendingTimelock.value, timelock, "pendingTimelock.value");
        assertEq(pendingTimelock.validAt, block.timestamp + TIMELOCK, "pendingTimelock.validAt");
    }

    function testSubmitTimelockAlreadyPending(uint256 timelock) public {
        timelock = bound(timelock, ConstantsLib.MIN_TIMELOCK, TIMELOCK - 1);

        vm.prank(OWNER);
        vault.submitTimelock(timelock);

        vm.expectRevert(ErrorsLib.AlreadyPending.selector);
        vm.prank(OWNER);
        vault.submitTimelock(timelock);
    }

    function testSubmitTimelockNotOwner(uint256 timelock) public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        vault.submitTimelock(timelock);
    }

    function testDeploySiloVaultAboveMaxTimelock(uint256 timelock) public {
        timelock = bound(timelock, ConstantsLib.MAX_TIMELOCK + 1, type(uint256).max);

        vm.expectRevert(ErrorsLib.AboveMaxTimelock.selector);
        createSiloVault(OWNER,timelock, address(loanToken), "SiloVault Vault", "MMV");
    }

    /*
     FOUNDRY_PROFILE=vaults_tests forge test --ffi --mt testDeploySiloVaultBelowMinTimelock -vvv
    */
    function testDeploySiloVaultBelowMinTimelock(uint256 timelock) public {
        timelock = bound(timelock, 0, ConstantsLib.MIN_TIMELOCK - 1);

        vm.expectRevert(ErrorsLib.BelowMinTimelock.selector);
        createSiloVault(OWNER, timelock, address(loanToken), "SiloVault Vault", "MMV");
    }

    function testSubmitTimelockAboveMaxTimelock(uint256 timelock) public {
        timelock = bound(timelock, ConstantsLib.MAX_TIMELOCK + 1, type(uint256).max);

        vm.prank(OWNER);
        vm.expectRevert(ErrorsLib.AboveMaxTimelock.selector);
        vault.submitTimelock(timelock);
    }

    function testSubmitTimelockBelowMinTimelock(uint256 timelock) public {
        timelock = bound(timelock, 0, ConstantsLib.MIN_TIMELOCK - 1);

        vm.prank(OWNER);
        vm.expectRevert(ErrorsLib.BelowMinTimelock.selector);
        vault.submitTimelock(timelock);
    }

    function testSubmitTimelockAlreadySet() public {
        uint256 timelock = vault.timelock();

        vm.prank(OWNER);
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        vault.submitTimelock(timelock);
    }

    function testAcceptTimelock(uint256 timelock) public {
        timelock = bound(timelock, ConstantsLib.MIN_TIMELOCK, TIMELOCK - 1);

        vm.prank(OWNER);
        vault.submitTimelock(timelock);

        vm.warp(block.timestamp + TIMELOCK);

        vm.expectEmit(address(vault));
        emit EventsLib.SetTimelock(address(this), timelock);
        vault.acceptTimelock();

        uint256 newTimelock = vault.timelock();
        PendingUint192 memory pendingTimelock = vault.pendingTimelock();

        assertEq(newTimelock, timelock, "newTimelock");
        assertEq(pendingTimelock.value, 0, "pendingTimelock.value");
        assertEq(pendingTimelock.validAt, 0, "pendingTimelock.validAt");
    }

    function testAcceptTimelockNoPendingValue() public {
        vm.expectRevert(ErrorsLib.NoPendingValue.selector);
        vault.acceptTimelock();
    }

    function testAcceptTimelockTimelockNotElapsed(uint256 timelock, uint256 elapsed) public {
        timelock = bound(timelock, ConstantsLib.MIN_TIMELOCK, TIMELOCK - 1);
        elapsed = bound(elapsed, 1, TIMELOCK - 1);

        vm.prank(OWNER);
        vault.submitTimelock(timelock);

        vm.warp(block.timestamp + elapsed);

        vm.expectRevert(ErrorsLib.TimelockNotElapsed.selector);
        vault.acceptTimelock();
    }

    function testSubmitGuardian() public {
        address guardian = makeAddr("Guardian2");

        vm.expectEmit();
        emit EventsLib.SubmitGuardian(guardian);
        vm.prank(OWNER);
        vault.submitGuardian(guardian);

        address newGuardian = vault.guardian();
        PendingAddress memory pendingGuardian = vault.pendingGuardian();

        assertEq(newGuardian, GUARDIAN, "newGuardian");
        assertEq(pendingGuardian.value, guardian, "pendingGuardian.value");
        assertEq(pendingGuardian.validAt, block.timestamp + TIMELOCK, "pendingGuardian.validAt");
    }

    function testSubmitGuardianFromZero() public {
        _setGuardian(address(0));

        vm.expectEmit(address(vault));
        emit EventsLib.SetGuardian(OWNER, GUARDIAN);
        vm.prank(OWNER);
        vault.submitGuardian(GUARDIAN);

        address newGuardian = vault.guardian();
        PendingAddress memory pendingGuardian = vault.pendingGuardian();

        assertEq(newGuardian, GUARDIAN, "newGuardian");
        assertEq(pendingGuardian.value, address(0), "pendingGuardian.value");
        assertEq(pendingGuardian.validAt, 0, "pendingGuardian.validAt");
    }

    function testSubmitGuardianZero() public {
        vm.prank(OWNER);
        vault.submitGuardian(address(0));

        address newGuardian = vault.guardian();
        PendingAddress memory pendingGuardian = vault.pendingGuardian();

        assertEq(newGuardian, GUARDIAN, "newGuardian");
        assertEq(pendingGuardian.value, address(0), "pendingGuardian.value");
        assertEq(pendingGuardian.validAt, block.timestamp + TIMELOCK, "pendingGuardian.validAt");
    }

    function testSubmitGuardianAlreadyPending() public {
        address guardian = makeAddr("Guardian2");

        vm.prank(OWNER);
        vault.submitGuardian(guardian);

        vm.expectRevert(ErrorsLib.AlreadyPending.selector);
        vm.prank(OWNER);
        vault.submitGuardian(guardian);
    }

    function testAcceptGuardian() public {
        address guardian = makeAddr("Guardian2");

        vm.prank(OWNER);
        vault.submitGuardian(guardian);

        vm.warp(block.timestamp + TIMELOCK);

        vm.expectEmit(address(vault));
        emit EventsLib.SetGuardian(address(this), guardian);
        vault.acceptGuardian();

        address newGuardian = vault.guardian();
        PendingAddress memory pendingGuardian = vault.pendingGuardian();

        assertEq(newGuardian, guardian, "newGuardian");
        assertEq(pendingGuardian.value, address(0), "pendingGuardian.value");
        assertEq(pendingGuardian.validAt, 0, "pendingGuardian.validAt");
    }

    function testAcceptGuardianTimelockIncreased(uint256 timelock, uint256 elapsed) public {
        timelock = bound(timelock, TIMELOCK + 1, ConstantsLib.MAX_TIMELOCK);
        elapsed = bound(elapsed, TIMELOCK + 1, timelock);

        address guardian = makeAddr("Guardian2");

        vm.prank(OWNER);
        vault.submitGuardian(guardian);

        _setTimelock(timelock);

        vm.warp(block.timestamp + elapsed);

        vm.expectEmit(address(vault));
        emit EventsLib.SetGuardian(address(this), guardian);
        vault.acceptGuardian();

        address newGuardian = vault.guardian();
        PendingAddress memory pendingGuardian = vault.pendingGuardian();

        assertEq(newGuardian, guardian, "newGuardian");
        assertEq(pendingGuardian.value, address(0), "pendingGuardian.value");
        assertEq(pendingGuardian.validAt, 0, "pendingGuardian.validAt");
    }

    function testAcceptGuardianTimelockDecreased(uint256 timelock, uint256 elapsed) public {
        timelock = bound(timelock, ConstantsLib.MIN_TIMELOCK, TIMELOCK - 1);
        elapsed = bound(elapsed, 1, TIMELOCK - 1);

        vm.prank(OWNER);
        vault.submitTimelock(timelock);

        vm.warp(block.timestamp + elapsed);

        address guardian = makeAddr("Guardian2");

        vm.prank(OWNER);
        vault.submitGuardian(guardian);

        vm.warp(block.timestamp + TIMELOCK - elapsed);

        vault.acceptTimelock();

        vm.expectRevert(ErrorsLib.TimelockNotElapsed.selector);
        vault.acceptGuardian();
    }

    function testAcceptGuardianNoPendingValue() public {
        vm.expectRevert(ErrorsLib.NoPendingValue.selector);
        vault.acceptGuardian();
    }

    function testAcceptGuardianTimelockNotElapsed(uint256 elapsed) public {
        elapsed = bound(elapsed, 1, TIMELOCK - 1);

        address guardian = makeAddr("Guardian2");

        vm.prank(OWNER);
        vault.submitGuardian(guardian);

        vm.warp(block.timestamp + elapsed);

        vm.expectRevert(ErrorsLib.TimelockNotElapsed.selector);
        vault.acceptGuardian();
    }

    function testSubmitCapDecreased(uint256 cap) public {
        cap = bound(cap, 0, CAP - 1);

        IERC4626 market = allMarkets[0];

        vm.expectEmit(address(vault));
        emit EventsLib.SetCap(CURATOR, market, cap);
        vm.prank(CURATOR);
        vault.submitCap(market, cap);

        MarketConfig memory marketConfig = vault.config(market);
        PendingUint192 memory pendingCap = vault.pendingCap(market);

        assertEq(marketConfig.cap, cap, "marketConfig.cap");
        assertEq(marketConfig.enabled, true, "marketConfig.enabled");
        assertEq(marketConfig.removableAt, 0, "marketConfig.removableAt");
        assertEq(pendingCap.value, 0, "pendingCap.value");
        assertEq(pendingCap.validAt, 0, "pendingCap.validAt");
    }

    function testSubmitCapIncreased(uint256 cap) public {
        cap = bound(cap, 1, type(uint184).max);

        IERC4626 market = allMarkets[1];

        vm.expectEmit(address(vault));
        emit EventsLib.SubmitCap(CURATOR, market, cap);
        vm.prank(CURATOR);
        vault.submitCap(market, cap);

        MarketConfig memory marketConfig = vault.config(market);
        PendingUint192 memory pendingCap = vault.pendingCap(market);

        assertEq(marketConfig.cap, 0, "marketConfig.cap");
        assertEq(marketConfig.enabled, false, "marketConfig.enabled");
        assertEq(marketConfig.removableAt, 0, "marketConfig.removableAt");
        assertEq(pendingCap.value, cap, "pendingCap.value");
        assertEq(pendingCap.validAt, block.timestamp + TIMELOCK, "pendingCap.validAt");
        assertEq(vault.supplyQueueLength(), 2, "supplyQueueLength");
        assertEq(vault.withdrawQueueLength(), 2, "withdrawQueueLength");
    }

    function testSubmitCapAlreadyPending(uint256 cap) public {
        cap = bound(cap, 1, type(uint184).max);

        IERC4626 market = allMarkets[1];

        vm.prank(CURATOR);
        vault.submitCap(market, cap);

        vm.expectRevert(ErrorsLib.AlreadyPending.selector);
        vm.prank(CURATOR);
        vault.submitCap(market, cap);
    }

    function testAcceptCapIncreased(uint256 cap) public {
        cap = bound(cap, CAP + 1, type(uint184).max);

        IERC4626 market = allMarkets[0];

        vm.prank(CURATOR);
        vault.submitCap(market, cap);

        vm.warp(block.timestamp + TIMELOCK);

        vm.expectEmit(address(vault));
        emit EventsLib.SetCap(address(this), market, cap);
        vault.acceptCap(market);

        MarketConfig memory marketConfig = vault.config(market);
        PendingUint192 memory pendingCap = vault.pendingCap(market);

        assertEq(marketConfig.cap, cap, "marketConfig.cap");
        assertEq(marketConfig.enabled, true, "marketConfig.enabled");
        assertEq(marketConfig.removableAt, 0, "marketConfig.removableAt");
        assertEq(pendingCap.value, 0, "pendingCap.value");
        assertEq(pendingCap.validAt, 0, "pendingCap.validAt");
        assertEq(address(vault.supplyQueue(1)), address(market), "supplyQueue");
        assertEq(address(vault.withdrawQueue(1)), address(market), "withdrawQueue");
    }

    function testAcceptCapIncreasedTimelockIncreased(uint256 cap, uint256 timelock, uint256 elapsed) public {
        cap = bound(cap, CAP + 1, type(uint184).max);
        timelock = bound(timelock, TIMELOCK + 1, ConstantsLib.MAX_TIMELOCK);
        elapsed = bound(elapsed, TIMELOCK + 1, timelock);

        IERC4626 market = allMarkets[0];

        vm.prank(CURATOR);
        vault.submitCap(market, cap);

        _setTimelock(timelock);

        vm.warp(block.timestamp + elapsed);

        vm.expectEmit();
        emit EventsLib.SetCap(address(this), market, cap);
        vault.acceptCap(market);

        MarketConfig memory marketConfig = vault.config(market);
        PendingUint192 memory pendingCap = vault.pendingCap(market);

        assertEq(marketConfig.cap, cap, "marketConfig.cap");
        assertEq(marketConfig.enabled, true, "marketConfig.enabled");
        assertEq(marketConfig.removableAt, 0, "marketConfig.removableAt");
        assertEq(pendingCap.value, 0, "pendingCap.value");
        assertEq(pendingCap.validAt, 0, "pendingCap.validAt");
        assertEq(address(vault.supplyQueue(1)), address(market), "supplyQueue");
        assertEq(address(vault.withdrawQueue(1)), address(market), "withdrawQueue");
    }

    function testAcceptCapIncreasedTimelockDecreased(uint256 cap, uint256 timelock, uint256 elapsed) public {
        cap = bound(cap, CAP + 1, type(uint184).max);
        timelock = bound(timelock, ConstantsLib.MIN_TIMELOCK, TIMELOCK - 1);
        elapsed = bound(elapsed, 1, TIMELOCK - 1);

        vm.prank(OWNER);
        vault.submitTimelock(timelock);

        vm.warp(block.timestamp + elapsed);

        IERC4626 market = allMarkets[0];

        vm.prank(CURATOR);
        vault.submitCap(market, cap);

        vm.warp(block.timestamp + TIMELOCK - elapsed);

        vault.acceptTimelock();

        vm.expectRevert(ErrorsLib.TimelockNotElapsed.selector);
        vault.acceptCap(market);
    }

    function testAcceptCapNoPendingValue() public {
        vm.expectRevert(ErrorsLib.NoPendingValue.selector);
        vault.acceptCap(allMarkets[0]);
    }

    function testAcceptCapTimelockNotElapsed(uint256 elapsed) public {
        elapsed = bound(elapsed, 0, TIMELOCK - 1);

        vm.prank(CURATOR);
        vault.submitCap(allMarkets[1], CAP);

        vm.warp(block.timestamp + elapsed);

        vm.expectRevert(ErrorsLib.TimelockNotElapsed.selector);
        vault.acceptCap(allMarkets[1]);
    }

    function testSubmitMarketRemoval() public {
        IERC4626 market = allMarkets[0];

        _setCap(market, 0);

        vm.prank(CURATOR);
        vault.submitMarketRemoval(market);

        MarketConfig memory marketConfig = vault.config(market);

        assertEq(marketConfig.cap, 0, "marketConfig.cap");
        assertEq(marketConfig.enabled, true, "marketConfig.enabled");
        assertEq(marketConfig.removableAt, block.timestamp + TIMELOCK, "marketConfig.removableAt");
    }

    function testSubmitMarketRemovalMarketNotEnabled() public {
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.MarketNotEnabled.selector, allMarkets[1]));
        vm.prank(CURATOR);
        vault.submitMarketRemoval(allMarkets[1]);
    }
}
