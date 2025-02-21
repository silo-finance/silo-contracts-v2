// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {stdError} from "forge-std/StdError.sol";

import {SafeCast} from "openzeppelin5/utils/math/SafeCast.sol";
import {IERC4626, IERC20} from "openzeppelin5/interfaces/IERC4626.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {ErrorsLib} from "../../contracts/libraries/ErrorsLib.sol";
import {EventsLib} from "../../contracts/libraries/EventsLib.sol";
import {ConstantsLib} from "../../contracts/libraries/ConstantsLib.sol";

import {IntegrationTest} from "./helpers/IntegrationTest.sol";
import {CAP, MAX_TEST_ASSETS, MIN_TEST_ASSETS, TIMELOCK} from "./helpers/BaseTest.sol";

/*
 FOUNDRY_PROFILE=vaults-tests forge test --ffi --mc MarketTest -vvv
*/
contract MarketTest is IntegrationTest {

    function setUp() public override {
        super.setUp();

        _setCap(allMarkets[0], CAP);
        _setCap(allMarkets[1], CAP);
        _setCap(allMarkets[2], CAP);
    }


    /*
     FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt testAllowanceOnSetCap -vvv
    */
    function testAllowanceOnSetCap() public {
        IERC4626 market = allMarkets[0];
        IERC20 asset = IERC20(market.asset());

        assertEq(
            asset.allowance(address(vault), address(market)),
            type(uint256).max,
            "allowance is in use"
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
    FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt testSubmitCapInconsistentAsset -vvv
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
     FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt testEnableMarketWithLiquidity -vvv
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

     Description: As the markets themselves are ERC4626, a share inflation attack (first depositor) in any of them may
     result in the vault being drained, as users can call the reallocateTo() or the deposit() functions to constantly
     deposit into the vulnerable ERC4626 and lose funds.

The way the standard implementation of ERC4626 deals with a first depositor attack is by making such attack unprofitable
 for an attacker, which will discourage anyone from actually inflating the share price. An attacker would need to invest
 a certain amount of funds in order to inflate the price, and that amount must be greater than any loss caused due to
 rounding to any future depositor.

The implied assumption is that the victim must be front-runned and will not repeat this deposit more than once.
This assumption does not actually hold true in our case because the attacker has some control over the Silo Vault.
 He can control how many times the vault deposits into the ERC4626 market, repeating this action as many times
 as he wants via the reallocateTo() function in the PublicAllocator.sol contract which would cost the attacker some fees,
 or via the deposit() function if the vulnerable market is the next market in the supplyQueue (This could be forced by
 taking a large flashloan and filling up the caps of the markets ahead of it in the queue), and controlling the amount
 that is being deposited (making it such that the rounding errors would be most impactful).



While it would be best for an attacker if he would be able to inflate the share price in any regular market (as he would
be able to be a shareholder in that market and gain the funds that the Silo Vault will lose), there’s no guarantee that
it would be possible. However, the Idle Vault should always be vulnerable to a share price inflation attack. It inherits
 from the standard ERC4626 implementation and it restricts anyone who isn't the Silo Vault from being a shareholder.
  In that case, the attacker can forcibly make the Silo Vault withdraw the funds from there (if caps allow it)
  and inflate the share price through a donation. After the inflation, the attacker can force the Silo Vault
   to deposit funds into the Idle Vault that will be lost due to rounding, causing a permanent loss of funds,
   as they will be owned by the “virtual user” in the Idle Vault.



Recommendations: Firstly, we would recommend adding a sanity check that whenever the Silo Vault deposits funds into
an ERC4626 market, the difference in Silo Vault-owned assets reported by the market is not too different from the
 amount that was actually deposited. Secondly, we would recommend setting the _decimalsOffset() in the Idle Vault to be
 very large (say, 18). This would make the amount that the user would need to "gift" the market in order to significantly
 inflate the share price very large and impractical.

Lastly, we would also recommend making a design change and cap the amounts that could be deposited
(decrease back when funds are withdrawn) into each market (and not just the amount that it currently holds
on the Silo Vault's behalf). This could limit any damage to the Silo Vault that could occur as a result of a faulty market.

     FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt testInflationAttackWithDonation -vvv

    */
    function testInflationAttackWithDonation(
        uint64 deposit1, uint64 deposit2, uint64 donation
    ) public {
//        (uint64 deposit1, uint64 deposit2, uint64 donation) = (12, 250923041328, 158581482927923 );
        vm.assume(uint256(deposit1) * deposit2 * donation != 0);
        vm.assume(deposit2 >= 2);

        address user = makeAddr("user");
        uint256 additionalSupply = 2;

        _setCap(allMarkets[0], 50);

        IERC4626[] memory supplyQueue = new IERC4626[](2);
        supplyQueue[0] = allMarkets[0];
        supplyQueue[1] = idleMarket;


        vm.prank(ALLOCATOR);
        vault.setSupplyQueue(supplyQueue);

        _setCap(supplyQueue[0], deposit1 / 2);
        _setCap(supplyQueue[1], type(uint128).max);

        assertEq(vault.supplyQueueLength(), 2, "only 2 markets");
        assertEq(address(vault.supplyQueue(1)), address(idleMarket), "ensure we have idle");

        vm.prank(user);
        vault.deposit(deposit1, user);

        emit log("donation!");
        IERC20(idleMarket.asset()).transfer(address(supplyQueue[1]), donation);

        vm.assume(vault.convertToShares(deposit2) != 0);

        vm.prank(SUPPLIER);
        vault.deposit(deposit2, SUPPLIER);
//
        _printData();

        vm.startPrank(user);
        assertLe(vault.redeem(vault.balanceOf(user), user, user), uint256(deposit1) + donation, "must be not profitable");
        vm.stopPrank();

        vm.startPrank(SUPPLIER);
        uint256 withdraw2 = vault.redeem(vault.balanceOf(SUPPLIER), SUPPLIER, SUPPLIER);

        if (withdraw2 < deposit2 - 2) {
            emit log_named_uint("SUPPLIER lost", deposit2 - 2 - withdraw2);
        }

        assertGe(
            withdraw2,
            deposit2 - 2,
            "there should be no loss (2 wei acceptable for two roundings)"
        );
        vm.stopPrank();
    }

    /*
    FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt testInflationAttack -vvv

    */
    function testInflationAttackWithRealocation(
        uint64 deposit1, uint64 deposit2, uint64 donation
    ) public {
//        (uint64 deposit1, uint64 deposit2, uint64 donation) = (12, 250923041328, 158581482927923 );
        vm.assume(uint256(deposit1) * deposit2 * donation != 0);

        address user = makeAddr("user");
        uint256 additionalSupply = 2;

        _setCap(allMarkets[0], 50);

        IERC4626[] memory supplyQueue = new IERC4626[](2);
        supplyQueue[0] = allMarkets[0];
        supplyQueue[1] = idleMarket;


        vm.prank(ALLOCATOR);
        vault.setSupplyQueue(supplyQueue);

        _setCap(supplyQueue[0], deposit1 / 2);
        _setCap(supplyQueue[1], type(uint128).max);

        assertEq(vault.supplyQueueLength(), 2, "only 2 markets");
        assertEq(address(vault.supplyQueue(1)), address(idleMarket), "ensure we have idle");

        vm.prank(user);
        vault.deposit(deposit1, user);

        emit log("donation!");
        IERC20(idleMarket.asset()).transfer(address(supplyQueue[1]), donation);

        vm.assume(vault.convertToShares(deposit2) != 0);

        vm.prank(SUPPLIER);
        vault.deposit(deposit2, SUPPLIER);
//
        _printData();

        vm.startPrank(user);
        uint256 shares = vault.balanceOf(user);
        uint256 assets = vault.redeem(shares, user, user);
        assertLe(assets, uint256(deposit1) + donation, "must be not profitable");
        vm.stopPrank();
    }

    function _printData() internal {
        address user = makeAddr("user");
        IERC20 asset = IERC20(allMarkets[0].asset());

        emit log("--------- dump:");
        emit log_named_address("allMarkets[0]", address(allMarkets[0]));
        emit log_named_address("   idleMarket", address(idleMarket));

        emit log_named_uint("asset.balanceOf(allMarkets[0])", asset.balanceOf(address(allMarkets[0])));
        emit log_named_uint("   asset.balanceOf(idleMarket)", asset.balanceOf(address(idleMarket)));

        emit log_named_uint("     SUPPLIER preview withdraw", vault.previewRedeem(vault.balanceOf(SUPPLIER)));
        emit log_named_uint("         user preview withdraw", vault.previewRedeem(vault.balanceOf(user)));

    }

    function testRevokeNoRevert() public {
        vm.startPrank(OWNER);
        vault.revokePendingTimelock();
        vault.revokePendingGuardian();
        vault.revokePendingCap(IERC4626(address(0)));
        vault.revokePendingMarketRemoval(IERC4626(address(0)));
        vm.stopPrank();
    }
}
