// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {stdError} from "forge-std/StdError.sol";

import {SafeCast} from "openzeppelin5/utils/math/SafeCast.sol";
import {IERC4626, IERC20} from "openzeppelin5/interfaces/IERC4626.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {ErrorsLib} from "../../contracts/libraries/ErrorsLib.sol";
import {EventsLib} from "../../contracts/libraries/EventsLib.sol";
import {ConstantsLib} from "../../contracts/libraries/ConstantsLib.sol";
import {ArbitraryLossThreshold} from "../../contracts/libraries/PendingLib.sol";

import {IntegrationTest} from "./helpers/IntegrationTest.sol";
import {CAP, MAX_TEST_ASSETS, MIN_TEST_ASSETS, TIMELOCK} from "./helpers/BaseTest.sol";

/*
 FOUNDRY_PROFILE=vaults_tests forge test --ffi --mc MarketTest -vvv
*/
contract MarketTest is IntegrationTest {

    function setUp() public override {
        super.setUp();

        _setCap(allMarkets[0], CAP);
        _setCap(allMarkets[1], CAP);
        _setCap(allMarkets[2], CAP);
    }


    /*
     FOUNDRY_PROFILE=vaults_tests forge test --ffi --mt testAllowanceOnSetCap -vvv
    */
    function testAllowanceOnSetCap() public {
        IERC4626 market = allMarkets[0];
        IERC20 asset = IERC20(market.asset());

        assertEq(
            asset.allowance(address(vault), address(market)),
            0,
            "allowance is ZERO after setCap"
        );

        _setCap(market, 0);

        assertEq(
            asset.allowance(address(vault), address(market)),
            0,
            "allowance is ZERO when cap is 0"
        );
    }

    function testMintAllCapsReached() public {
        vm.prank(ALLOCATOR);
        vault.setSupplyQueue(new IERC4626[](0));

        vm.prank(SUPPLIER);
        loanToken.approve(address(vault), type(uint256).max);

        vm.expectRevert(ErrorsLib.AllCapsReached.selector);
        vm.prank(SUPPLIER);
        vault.mint(1, RECEIVER);
    }

    function testDepositAllCapsReached() public {
        vm.prank(ALLOCATOR);
        vault.setSupplyQueue(new IERC4626[](0));

        vm.prank(SUPPLIER);
        loanToken.approve(address(vault), type(uint256).max);

        vm.expectRevert(ErrorsLib.AllCapsReached.selector);
        vm.prank(SUPPLIER);
        vault.deposit(1, RECEIVER);
    }

    function testSubmitCapOverflow(uint256 seed, uint256 cap) public {
        IERC4626 market = _randomMarket(seed);
        cap = bound(cap, uint256(type(uint184).max) + 1, type(uint256).max);

        vm.prank(CURATOR);
        vm.expectRevert(abi.encodeWithSelector(SafeCast.SafeCastOverflowedUintDowncast.selector, uint8(184), cap));
        vault.submitCap(market, cap);
    }

    /*
    FOUNDRY_PROFILE=vaults_tests forge test --ffi --mt testSubmitCapInconsistentAsset -vvv
    */
    function testSubmitCapInconsistentAsset() public {
        IERC4626 market = IERC4626(makeAddr("any market"));
        vm.mockCall(address(market), abi.encodeWithSelector(IERC4626.asset.selector), abi.encode(makeAddr("not loan token")));

        vm.assume(market.asset() != address(loanToken));

        vm.prank(CURATOR);
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.InconsistentAsset.selector, market));
        vault.submitCap(market, 0);
    }

    function testSubmitCapAlreadySet() public {
        vm.prank(CURATOR);
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        vault.submitCap(allMarkets[0], CAP);
    }

    function testSubmitCapAlreadyPending() public {
        vm.prank(CURATOR);
        vault.submitCap(allMarkets[0], CAP + 1);

        vm.prank(CURATOR);
        vm.expectRevert(ErrorsLib.AlreadyPending.selector);
        vault.submitCap(allMarkets[0], CAP + 1);
    }

    function testSubmitCapPendingRemoval() public {
        vm.startPrank(CURATOR);
        vault.submitCap(allMarkets[2], 0);
        vault.submitMarketRemoval(allMarkets[2]);

        vm.expectRevert(ErrorsLib.PendingRemoval.selector);
        vault.submitCap(allMarkets[2], CAP + 1);
    }

    function testSetSupplyQueue() public {
        IERC4626[] memory supplyQueue = new IERC4626[](2);
        supplyQueue[0] = allMarkets[1];
        supplyQueue[1] = allMarkets[2];

        vm.expectEmit();
        emit EventsLib.SetSupplyQueue(ALLOCATOR, supplyQueue);
        vm.prank(ALLOCATOR);
        vault.setSupplyQueue(supplyQueue);

        assertEq(address(vault.supplyQueue(0)), address(allMarkets[1]));
        assertEq(address(vault.supplyQueue(1)), address(allMarkets[2]));
    }

    function testSetSupplyQueueMaxQueueLengthExceeded() public {
        IERC4626[] memory supplyQueue = new IERC4626[](ConstantsLib.MAX_QUEUE_LENGTH + 1);

        vm.prank(ALLOCATOR);
        vm.expectRevert(ErrorsLib.MaxQueueLengthExceeded.selector);
        vault.setSupplyQueue(supplyQueue);
    }

    function testAcceptCapMaxQueueLengthExceeded() public {
        for (uint256 i = 3; i < ConstantsLib.MAX_QUEUE_LENGTH - 1; ++i) {
            _setCap(allMarkets[i], CAP);
        }

        _setTimelock(1 weeks);

        IERC4626 market = allMarkets[ConstantsLib.MAX_QUEUE_LENGTH];

        vm.prank(CURATOR);
        vault.submitCap(market, CAP);

        vm.warp(block.timestamp + 1 weeks);

        vm.expectRevert(ErrorsLib.MaxQueueLengthExceeded.selector);
        vault.acceptCap(market);
    }

    function testSetSupplyQueueUnauthorizedMarket() public {
        IERC4626[] memory supplyQueue = new IERC4626[](1);
        supplyQueue[0] = allMarkets[3];

        vm.prank(ALLOCATOR);
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.UnauthorizedMarket.selector, supplyQueue[0]));
        vault.setSupplyQueue(supplyQueue);
    }

    function testUpdateWithdrawQueue() public {
        uint256[] memory indexes = new uint256[](4);
        indexes[0] = 1;
        indexes[1] = 2;
        indexes[2] = 3;
        indexes[3] = 0;

        IERC4626[] memory expectedWithdrawQueue = new IERC4626[](4);
        expectedWithdrawQueue[0] = allMarkets[0];
        expectedWithdrawQueue[1] = allMarkets[1];
        expectedWithdrawQueue[2] = allMarkets[2];
        expectedWithdrawQueue[3] = idleMarket;

        vm.expectEmit(address(vault));
        emit EventsLib.SetWithdrawQueue(ALLOCATOR, expectedWithdrawQueue);
        vm.prank(ALLOCATOR);
        vault.updateWithdrawQueue(indexes);

        assertEq(address(vault.withdrawQueue(0)), address(expectedWithdrawQueue[0]));
        assertEq(address(vault.withdrawQueue(1)), address(expectedWithdrawQueue[1]));
        assertEq(address(vault.withdrawQueue(2)), address(expectedWithdrawQueue[2]));
        assertEq(address(vault.withdrawQueue(3)), address(expectedWithdrawQueue[3]));
    }

    function testUpdateWithdrawQueueRemovingDisabledMarket() public {
        _setCap(allMarkets[2], 0);

        vm.prank(CURATOR);
        vault.submitMarketRemoval(allMarkets[2]);

        vm.warp(block.timestamp + TIMELOCK);

        uint256[] memory indexes = new uint256[](3);
        indexes[0] = 0;
        indexes[1] = 2;
        indexes[2] = 1;

        IERC4626[] memory expectedWithdrawQueue = new IERC4626[](3);
        expectedWithdrawQueue[0] = idleMarket;
        expectedWithdrawQueue[1] = allMarkets[1];
        expectedWithdrawQueue[2] = allMarkets[0];

        vm.expectEmit();
        emit EventsLib.SetWithdrawQueue(ALLOCATOR, expectedWithdrawQueue);
        vm.prank(ALLOCATOR);
        vault.updateWithdrawQueue(indexes);

        assertEq(address(vault.withdrawQueue(0)), address(expectedWithdrawQueue[0]));
        assertEq(address(vault.withdrawQueue(1)), address(expectedWithdrawQueue[1]));
        assertEq(address(vault.withdrawQueue(2)), address(expectedWithdrawQueue[2]));
        assertFalse(vault.config(allMarkets[2]).enabled);
        assertEq(vault.pendingCap(allMarkets[2]).value, 0, "pendingCap.value");
        assertEq(vault.pendingCap(allMarkets[2]).validAt, 0, "pendingCap.validAt");
    }

    function testSubmitMarketRemoval() public {
        vm.startPrank(CURATOR);
        vault.submitCap(allMarkets[2], 0);
        vm.expectEmit();
        emit EventsLib.SubmitMarketRemoval(CURATOR, allMarkets[2]);
        vault.submitMarketRemoval(allMarkets[2]);
        vm.stopPrank();

        assertEq(vault.config(allMarkets[2]).cap, 0);
        assertEq(vault.config(allMarkets[2]).removableAt, block.timestamp + TIMELOCK);
    }

    function testSubmitMarketRemovalPendingCap() public {
        vm.startPrank(CURATOR);
        vault.submitCap(allMarkets[2], 0);
        vault.submitCap(allMarkets[2], vault.config(allMarkets[2]).cap + 1);
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.PendingCap.selector, allMarkets[2]));
        vault.submitMarketRemoval(allMarkets[2]);
        vm.stopPrank();
    }

    function testSubmitMarketRemovalNonZeroCap() public {
        vm.startPrank(CURATOR);
        vm.expectRevert(ErrorsLib.NonZeroCap.selector);
        vault.submitMarketRemoval(allMarkets[2]);
        vm.stopPrank();
    }

    function testSubmitMarketRemovalAlreadyPending() public {
        vm.startPrank(CURATOR);
        vault.submitCap(allMarkets[2], 0);
        vault.submitMarketRemoval(allMarkets[2]);
        vm.expectRevert(ErrorsLib.AlreadyPending.selector);
        vault.submitMarketRemoval(allMarkets[2]);
        vm.stopPrank();
    }

    function testUpdateWithdrawQueueInvalidIndex() public {
        uint256[] memory indexes = new uint256[](4);
        indexes[0] = 1;
        indexes[1] = 2;
        indexes[2] = 3;
        indexes[3] = 4;

        vm.prank(ALLOCATOR);
        vm.expectRevert(stdError.indexOOBError);
        vault.updateWithdrawQueue(indexes);
    }

    function testUpdateWithdrawQueueDuplicateMarket() public {
        uint256[] memory indexes = new uint256[](4);
        indexes[0] = 1;
        indexes[1] = 2;
        indexes[2] = 1;
        indexes[3] = 3;

        vm.prank(ALLOCATOR);
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.DuplicateMarket.selector, allMarkets[0]));
        vault.updateWithdrawQueue(indexes);
    }

    function testUpdateWithdrawQueueInvalidMarketRemovalNonZeroSupply() public {
        vm.prank(SUPPLIER);
        vault.deposit(1, RECEIVER);

        uint256[] memory indexes = new uint256[](3);
        indexes[0] = 1;
        indexes[1] = 2;
        indexes[2] = 3;

        _setCap(idleMarket, 0);

        vm.prank(ALLOCATOR);
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.InvalidMarketRemovalNonZeroSupply.selector, idleMarket));
        vault.updateWithdrawQueue(indexes);
    }

    function testUpdateWithdrawQueueInvalidMarketRemovalNonZeroCap() public {
        uint256[] memory indexes = new uint256[](3);
        indexes[0] = 1;
        indexes[1] = 2;
        indexes[2] = 3;

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.InvalidMarketRemovalNonZeroCap.selector, idleMarket));

        vm.prank(ALLOCATOR);
        vault.updateWithdrawQueue(indexes);
    }

    function testUpdateWithdrawQueueInvalidMarketRemovalTimelockNotElapsed(uint256 elapsed) public {
        elapsed = bound(elapsed, 0, TIMELOCK - 1);

        vm.prank(SUPPLIER);
        vault.deposit(1, RECEIVER);

        _setCap(idleMarket, 0);

        vm.prank(CURATOR);
        vault.submitMarketRemoval(idleMarket);

        vm.warp(block.timestamp + elapsed);

        uint256[] memory indexes = new uint256[](3);
        indexes[0] = 1;
        indexes[1] = 2;
        indexes[2] = 3;

        vm.prank(ALLOCATOR);
        vm.expectRevert(
            abi.encodeWithSelector(ErrorsLib.InvalidMarketRemovalTimelockNotElapsed.selector, idleMarket)
        );
        vault.updateWithdrawQueue(indexes);
    }

    function testUpdateWithdrawQueueInvalidMarketRemovalPendingCap(uint256 cap) public {
        cap = bound(cap, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        _setCap(allMarkets[2], 0);
        vm.prank(CURATOR);
        vault.submitCap(allMarkets[2], cap);

        uint256[] memory indexes = new uint256[](3);
        indexes[0] = 0;
        indexes[1] = 2;
        indexes[2] = 1;

        vm.prank(ALLOCATOR);
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.PendingCap.selector, allMarkets[2]));
        vault.updateWithdrawQueue(indexes);
    }

    /*
     FOUNDRY_PROFILE=vaults_tests forge test --ffi --mt testEnableMarketWithLiquidity -vvv
    */
    function testEnableMarketWithLiquidity(uint256 deposited, uint256 additionalSupply, uint256 blocks) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);
        additionalSupply = bound(additionalSupply, MIN_TEST_ASSETS, MAX_TEST_ASSETS);
        blocks = _boundBlocks(blocks);

        IERC4626[] memory supplyQueue = new IERC4626[](1);
        supplyQueue[0] = allMarkets[0];

        _setCap(allMarkets[0], deposited);

        vm.prank(ALLOCATOR);
        vault.setSupplyQueue(supplyQueue);

        vm.startPrank(SUPPLIER);
        vault.deposit(deposited, ONBEHALF);
        allMarkets[3].deposit(additionalSupply, address(vault));
        vm.stopPrank();

        // collateral = toBorrow * maxLtv;
        uint256 collateral = deposited * 1e18 / 0.75e18 + 1;

        vm.startPrank(BORROWER);
        collateralMarkets[allMarkets[0]].deposit(collateral, BORROWER);
        ISilo(address(allMarkets[0])).borrow(deposited, BORROWER, BORROWER);
        vm.stopPrank();

        _forward(blocks);

        _setCap(allMarkets[3], CAP);

        assertEq(vault.lastTotalAssets(), deposited + additionalSupply);
    }

    /*
    FOUNDRY_PROFILE=vaults_tests forge test --ffi --mt test_setArbitraryLossThreshold -vvv
    */
    function test_setArbitraryLossThreshold() public {
        IERC4626 market = allMarkets[0];

        vm.startPrank(vault.owner());
        vault.submitGuardian(GUARDIAN);

        vm.startPrank(GUARDIAN);

        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        vault.setArbitraryLossThreshold(market, 0);

        vault.setArbitraryLossThreshold(market, 100);

        ArbitraryLossThreshold memory arbitraryLossThreshold = vault.arbitraryLossThreshold(market);

        assertEq(arbitraryLossThreshold.threshold, 100, "arbitraryLossThreshold set");

        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        vault.setArbitraryLossThreshold(market, 100);

        vault.setArbitraryLossThreshold(market, 50);

        arbitraryLossThreshold = vault.arbitraryLossThreshold(market);

        assertEq(arbitraryLossThreshold.threshold, 50, "arbitraryLossThreshold set");

        vm.stopPrank();
    }

    /*
    FOUNDRY_PROFILE=vaults_tests forge test --ffi --mt test_noAllowanceIfDepositFailed -vvv
    */
    function test_noAllowanceIfDepositFailed() public {
        address anyMarket = makeAddr("any market");
        IERC4626 secondMarket = allMarkets[0];

        prepareAnyMarketSetup();

        uint256 depositAmount = type(uint32).max;

        vm.mockCall(
            anyMarket,
            abi.encodeWithSelector(IERC4626.maxDeposit.selector, address(vault)),
            abi.encode(type(uint128).max)
        );

        vm.mockCall(
            anyMarket,
            abi.encodeWithSelector(IERC4626.previewDeposit.selector, depositAmount),
            abi.encode(1)
        );

        // simulate deposit failure
        vm.mockCallRevert(
            anyMarket,
            abi.encodeWithSelector(IERC4626.deposit.selector, depositAmount, address(vault)),
            abi.encode(false)
        );

        vm.prank(SUPPLIER);
        vault.deposit(depositAmount, SUPPLIER);

        IERC20 asset = IERC20(vault.asset());

        // market with failed deposit should have no allowance
        assertEq(asset.allowance(address(vault), anyMarket), 1, "[0] allowance should be ZERO");
        // market with successful deposit should have no allowance
        assertEq(asset.allowance(address(vault), address(secondMarket)), 1, "[1] allowance should be ZERO");
    }

    /*
    FOUNDRY_PROFILE=vaults_tests forge test --ffi --mt test_MaxDepositCap -vvv
    */
    function test_MaxDepositCap() public {
        address anyMarket = makeAddr("any market");
        IERC4626 secondMarket = allMarkets[0];

        prepareAnyMarketSetup();

        uint256 depositAmount = type(uint32).max;

        uint256 maxAnyDeposit = 1;
        uint256 anyShares = 1000;

        vm.mockCall(
            anyMarket,
            abi.encodeWithSelector(IERC4626.maxDeposit.selector, address(vault)),
            abi.encode(maxAnyDeposit)
        );

        vm.mockCall(
            anyMarket,
            abi.encodeWithSelector(IERC4626.previewDeposit.selector, maxAnyDeposit),
            abi.encode(anyShares)
        );

        vm.mockCall(
            anyMarket,
            abi.encodeWithSelector(IERC4626.deposit.selector, 1, address(vault)),
            abi.encode(anyShares)
        );

        vm.mockCall(
            anyMarket,
            abi.encodeWithSelector(IERC4626.previewRedeem.selector, anyShares),
            abi.encode(maxAnyDeposit)
        );

        vm.prank(SUPPLIER);
        vault.deposit(depositAmount, SUPPLIER);

        IERC20 asset = IERC20(vault.asset());

        assertEq(asset.balanceOf(address(secondMarket)), depositAmount - 1, "because of maxDeposit second market got all - 1");
    }

    /*
    FOUNDRY_PROFILE=vaults_tests forge test --ffi --mt test_noDepositWhenPreviewZero -vvv
    */
    function test_noDepositWhenPreviewZero() public {
        address anyMarket = makeAddr("any market");
        IERC4626 secondMarket = allMarkets[0];

        prepareAnyMarketSetup();

        uint256 depositAmount = type(uint32).max;

        vm.mockCall(
            anyMarket,
            abi.encodeWithSelector(IERC4626.maxDeposit.selector, address(vault)),
            abi.encode(depositAmount)
        );

        vm.mockCall(
            anyMarket,
            abi.encodeWithSelector(IERC4626.previewDeposit.selector, depositAmount),
            abi.encode(0)
        );

        vm.prank(SUPPLIER);
        vault.deposit(depositAmount, SUPPLIER);

        IERC20 asset = IERC20(vault.asset());

        assertEq(asset.balanceOf(address(secondMarket)), depositAmount, "second market got all");
    }

    function testRevokeNoRevert() public {
        vm.startPrank(OWNER);
        vault.revokePendingTimelock();
        vault.revokePendingGuardian();
        vault.revokePendingCap(IERC4626(address(0)));
        vault.revokePendingMarketRemoval(IERC4626(address(0)));
        vm.stopPrank();
    }

    function prepareAnyMarketSetup() private {
        address anyMarket = makeAddr("any market");

        IERC4626[] memory supplyQueue = new IERC4626[](2);
        supplyQueue[0] = IERC4626(anyMarket);
        supplyQueue[1] = allMarkets[0];

        vm.mockCall(anyMarket, abi.encodeWithSelector(IERC4626.asset.selector), abi.encode(vault.asset()));
        vm.mockCall(anyMarket, abi.encodeWithSelector(IERC20.balanceOf.selector, address(vault)), abi.encode(0));

        _setCap(supplyQueue[0], type(uint64).max);
        _setCap(supplyQueue[1], type(uint64).max);

        vm.prank(ALLOCATOR);
        vault.setSupplyQueue(supplyQueue);

        assertEq(address(vault.supplyQueue(0)), address(supplyQueue[0]));
    }
}
