// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {IERC20Errors} from "openzeppelin5/interfaces/draft-IERC6093.sol";
import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";
import {Math} from "openzeppelin5/token/ERC20/extensions/ERC4626.sol";

import {IERC3156FlashBorrower} from "silo-core/contracts/interfaces/IERC3156FlashBorrower.sol";

import {ErrorsLib} from "../../contracts/libraries/ErrorsLib.sol";
import {EventsLib} from "../../contracts/libraries/EventsLib.sol";

import {IntegrationTest} from "./helpers/IntegrationTest.sol";
import {CAP, MIN_TEST_ASSETS, MAX_TEST_ASSETS, TIMELOCK} from "./helpers/BaseTest.sol";

/*
 FOUNDRY_PROFILE=vaults-tests forge test --ffi --mc ERC4626Test -vvv
*/
contract ERC4626Test is IntegrationTest, IERC3156FlashBorrower {
    function setUp() public override {
        super.setUp();

        _setCap(allMarkets[0], CAP);
        _sortSupplyQueueIdleLast();
    }

    /*
     FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt testDecimals -vvv
    */
    function testDecimals(uint8 decimals) public {
        vm.mockCall(address(loanToken), abi.encodeWithSignature("decimals()"), abi.encode(decimals));

        vault = createSiloVault(OWNER, TIMELOCK, address(loanToken), "SiloVault Vault", "MMV");

        assertEq(vault.decimals(), Math.max(18, decimals), "decimals");
    }

    /*
     FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt testMint -vvv
    */
    function testMint(uint256 assets) public {
        assets = bound(assets, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        uint256 shares = vault.convertToShares(assets);

        vm.expectEmit();
        emit EventsLib.UpdateLastTotalAssets(vault.totalAssets() + assets);
        vm.prank(SUPPLIER);
        uint256 deposited = vault.mint(shares, ONBEHALF);

        assertGt(deposited, 0, "deposited");
        assertEq(loanToken.balanceOf(address(vault)), 0, "balanceOf(vault) 0, it was deposited to market");
        assertEq(vault.balanceOf(ONBEHALF), shares, "balanceOf(ONBEHALF)");
        assertEq(_expectedSupplyAssets(allMarkets[0], address(vault)), assets, "expectedSupplyAssets(vault)");
    }

    /*
     FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt testDeposit -vvv
    */
    function testDeposit(uint256 assets) public {
        assets = bound(assets, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        vm.expectEmit();
        emit EventsLib.UpdateLastTotalAssets(vault.totalAssets() + assets);
        vm.prank(SUPPLIER);
        uint256 shares = vault.deposit(assets, ONBEHALF);

        assertGt(shares, 0, "shares");
        assertEq(loanToken.balanceOf(address(vault)), 0, "balanceOf(vault)");
        assertEq(vault.balanceOf(ONBEHALF), shares, "balanceOf(ONBEHALF)");
        assertEq(_expectedSupplyAssets(allMarkets[0], address(vault)), assets, "expectedSupplyAssets(vault)");
    }

    /*
     FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt testRedeem -vvv
    */
    function testRedeem(uint256 deposited, uint256 redeemed) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        vm.prank(SUPPLIER);
        uint256 shares = vault.deposit(deposited, ONBEHALF);

        redeemed = bound(redeemed, 0, shares);

        vm.expectEmit();
        emit EventsLib.UpdateLastTotalAssets(vault.totalAssets() - vault.convertToAssets(redeemed));
        vm.prank(ONBEHALF);
        vault.redeem(redeemed, RECEIVER, ONBEHALF);

        assertEq(loanToken.balanceOf(address(vault)), 0, "balanceOf(vault)");
        assertEq(vault.balanceOf(ONBEHALF), shares - redeemed, "balanceOf(ONBEHALF)");
    }

    /*
     FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt testWithdraw -vvv
    */
    function testWithdraw(uint256 deposited, uint256 withdrawn) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);
        withdrawn = bound(withdrawn, 0, deposited);

        vm.prank(SUPPLIER);
        uint256 shares = vault.deposit(deposited, ONBEHALF);

        vm.expectEmit();
        emit EventsLib.UpdateLastTotalAssets(vault.totalAssets() - withdrawn);
        vm.prank(ONBEHALF);
        uint256 redeemed = vault.withdraw(withdrawn, RECEIVER, ONBEHALF);

        assertEq(loanToken.balanceOf(address(vault)), 0, "balanceOf(vault)");
        assertEq(vault.balanceOf(ONBEHALF), shares - redeemed, "balanceOf(ONBEHALF)");
    }

    /*
     FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt testWithdrawIdle -vvv
    */
    function testWithdrawIdle(uint256 deposited, uint256 withdrawn) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);
        withdrawn = bound(withdrawn, 0, deposited);

        _setCap(allMarkets[0], 0);

        vm.prank(SUPPLIER);
        uint256 shares = vault.deposit(deposited, ONBEHALF);

        vm.expectEmit();
        emit EventsLib.UpdateLastTotalAssets(vault.totalAssets() - withdrawn);
        vm.prank(ONBEHALF);
        uint256 redeemed = vault.withdraw(withdrawn, RECEIVER, ONBEHALF);

        assertEq(loanToken.balanceOf(address(vault)), 0, "balanceOf(vault)");
        assertEq(vault.balanceOf(ONBEHALF), shares - redeemed, "balanceOf(ONBEHALF)");
        assertEq(_idle(), deposited - withdrawn, "idle");
    }

    /*
     FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt testRedeemTooMuch -vvv
    */
    function testRedeemTooMuch(uint256 deposited) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        vm.startPrank(SUPPLIER);
        uint256 shares = vault.deposit(deposited, SUPPLIER);
        vault.deposit(deposited, ONBEHALF);
        vm.stopPrank();

        vm.prank(SUPPLIER);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, SUPPLIER, shares, shares + 1)
        );
        vault.redeem(shares + 1, RECEIVER, SUPPLIER);
    }

    /*
    FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt testWithdrawAll -vvv
    */
    function testWithdrawAll(uint256 assets) public {
        assets = bound(assets, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        vm.prank(SUPPLIER);
        uint256 minted = vault.deposit(assets, ONBEHALF);

        assertEq(vault.maxWithdraw(ONBEHALF), assets, "maxWithdraw(ONBEHALF)");

        vm.prank(ONBEHALF);
        uint256 shares = vault.withdraw(assets, RECEIVER, ONBEHALF);

        assertEq(shares, minted, "shares");
        assertEq(vault.balanceOf(ONBEHALF), 0, "balanceOf(ONBEHALF)");
        assertEq(loanToken.balanceOf(RECEIVER), assets, "loanToken.balanceOf(RECEIVER)");
        assertEq(_expectedSupplyAssets(allMarkets[0], address(vault)), 0, "expectedSupplyAssets(vault)");
    }

    /*
    FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt testRedeemAll -vvv
    */
    function testRedeemAll(uint256 deposited) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        vm.prank(SUPPLIER);
        uint256 minted = vault.deposit(deposited, ONBEHALF);

        assertEq(vault.maxRedeem(ONBEHALF), minted, "maxRedeem(ONBEHALF)");

        vm.prank(ONBEHALF);
        uint256 assets = vault.redeem(minted, RECEIVER, ONBEHALF);

        assertEq(assets, deposited, "assets");
        assertEq(vault.balanceOf(ONBEHALF), 0, "balanceOf(ONBEHALF)");
        assertEq(loanToken.balanceOf(RECEIVER), deposited, "loanToken.balanceOf(RECEIVER)");
        assertEq(_expectedSupplyAssets(allMarkets[0], address(vault)), 0, "expectedSupplyAssets(vault)");
    }

    /*
    FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt testRedeemNotDeposited -vvv
    */
    function testRedeemNotDeposited(uint256 deposited) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        vm.prank(SUPPLIER);
        uint256 shares = vault.deposit(deposited, ONBEHALF);

        vm.prank(SUPPLIER);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, SUPPLIER, 0, shares));
        vault.redeem(shares, SUPPLIER, SUPPLIER);
    }

    /*
    FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt testRedeemNotApproved -vvv
    */
    function testRedeemNotApproved(uint256 deposited) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        vm.prank(SUPPLIER);
        uint256 shares = vault.deposit(deposited, ONBEHALF);

        vm.prank(RECEIVER);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, RECEIVER, 0, shares));
        vault.redeem(shares, RECEIVER, ONBEHALF);
    }

    /*
    FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt testWithdrawNotApproved -vvv
    */
    function testWithdrawNotApproved(uint256 assets) public {
        assets = bound(assets, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        vm.prank(SUPPLIER);
        vault.deposit(assets, ONBEHALF);

        uint256 shares = vault.previewWithdraw(assets);
        vm.prank(RECEIVER);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, RECEIVER, 0, shares));
        vault.withdraw(assets, RECEIVER, ONBEHALF);
    }

    /*
    FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt testTransferFrom -vvv
    */
    function testTransferFrom(uint256 deposited, uint256 toTransfer) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        vm.prank(SUPPLIER);
        uint256 shares = vault.deposit(deposited, ONBEHALF);

        toTransfer = bound(toTransfer, 0, shares);

        vm.prank(ONBEHALF);
        vault.approve(SUPPLIER, toTransfer);

        vm.prank(SUPPLIER);
        vault.transferFrom(ONBEHALF, RECEIVER, toTransfer);

        assertEq(vault.balanceOf(ONBEHALF), shares - toTransfer, "balanceOf(ONBEHALF)");
        assertEq(vault.balanceOf(RECEIVER), toTransfer, "balanceOf(RECEIVER)");
        assertEq(vault.balanceOf(SUPPLIER), 0, "balanceOf(SUPPLIER)");
    }

    /*
    FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt testTransferFromNotApproved -vvv
    */
    function testTransferFromNotApproved(uint256 deposited, uint256 amount) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        vm.prank(SUPPLIER);
        uint256 shares = vault.deposit(deposited, ONBEHALF);

        amount = bound(amount, 0, shares);

        vm.prank(SUPPLIER);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, SUPPLIER, 0, shares));
        vault.transferFrom(ONBEHALF, RECEIVER, shares);
    }

    /*
    FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt testWithdrawMoreThanBalanceButLessThanTotalAssets -vvv
    */
    function testWithdrawMoreThanBalanceButLessThanTotalAssets(uint256 deposited, uint256 assets) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        vm.startPrank(SUPPLIER);
        uint256 shares = vault.deposit(deposited / 2, ONBEHALF);
        vault.deposit(deposited / 2, SUPPLIER);
        vm.stopPrank();

        assets = bound(assets, deposited / 2 + 1, vault.totalAssets());

        uint256 sharesBurnt = vault.previewWithdraw(assets);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, ONBEHALF, shares, sharesBurnt)
        );
        vm.prank(ONBEHALF);
        vault.withdraw(assets, RECEIVER, ONBEHALF);
    }

    /*
    FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt testWithdrawMoreThanTotalAssets -vvv
    */
    function testWithdrawMoreThanTotalAssets(uint256 deposited, uint256 assets) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        vm.prank(SUPPLIER);
        vault.deposit(deposited, ONBEHALF);

        assets = bound(assets, deposited + 1, type(uint256).max / (deposited + 1));

        vm.prank(ONBEHALF);
        vm.expectRevert(ErrorsLib.NotEnoughLiquidity.selector);
        vault.withdraw(assets, RECEIVER, ONBEHALF);
    }

    /*
    FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt testWithdrawMoreThanBalanceAndLiquidity -vvv
    */
    function testWithdrawMoreThanBalanceAndLiquidity(uint256 deposited, uint256 assets) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        vm.prank(SUPPLIER);
        vault.deposit(deposited, ONBEHALF);

        assets = bound(assets, deposited + 1, type(uint256).max / (deposited + 1));

        // Borrow liquidity.
        vm.startPrank(BORROWER);
        silo0.deposit(type(uint128).max, BORROWER);
        silo1.borrow(1, BORROWER, BORROWER);

        vm.startPrank(ONBEHALF);
        vm.expectRevert(ErrorsLib.NotEnoughLiquidity.selector);
        vault.withdraw(assets, RECEIVER, ONBEHALF);
    }

    /*
    FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt testTransfer -vvv
    */
    function testTransfer(uint256 deposited, uint256 toTransfer) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        vm.prank(SUPPLIER);
        uint256 minted = vault.deposit(deposited, ONBEHALF);

        toTransfer = bound(toTransfer, 0, minted);

        vm.prank(ONBEHALF);
        vault.transfer(RECEIVER, toTransfer);

        assertEq(vault.balanceOf(SUPPLIER), 0, "balanceOf(SUPPLIER)");
        assertEq(vault.balanceOf(ONBEHALF), minted - toTransfer, "balanceOf(ONBEHALF)");
        assertEq(vault.balanceOf(RECEIVER), toTransfer, "balanceOf(RECEIVER)");
    }

    /*
    FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt testMaxWithdraw -vvv
    */
    function testMaxWithdraw(uint256 depositedAssets, uint256 borrowedAssets) public {
        depositedAssets = bound(depositedAssets, MIN_TEST_ASSETS, MAX_TEST_ASSETS);
        borrowedAssets = bound(borrowedAssets, MIN_TEST_ASSETS, depositedAssets);

        vm.prank(SUPPLIER);
        vault.deposit(depositedAssets, ONBEHALF);

        vm.startPrank(BORROWER);
        silo0.deposit(type(uint128).max, BORROWER);
        silo1.borrow(borrowedAssets, BORROWER, BORROWER);

        assertEq(vault.maxWithdraw(ONBEHALF), depositedAssets - borrowedAssets, "maxWithdraw(ONBEHALF)");
    }

    /*
    FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt testMaxWithdrawFlashLoan -vvv
    */
    function testMaxWithdrawFlashLoan(uint256 supplied, uint256 deposited) public {
        supplied = bound(supplied, MIN_TEST_ASSETS, MAX_TEST_ASSETS);
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        vm.prank(SUPPLIER);
        silo1.deposit(supplied, ONBEHALF);

        vm.prank(SUPPLIER);
        vault.deposit(deposited, ONBEHALF);

        assertEq(vault.maxWithdraw(ONBEHALF), deposited, "maxWithdraw");
        assertEq(loanToken.balanceOf(address(silo1)), supplied + deposited, "balanceOf");

        silo1.flashLoan(
            IERC3156FlashBorrower(address(this)), address(loanToken), loanToken.balanceOf(address(silo1)), ""
        );
    }

    /*
    FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt testMaxDeposit -vvv
    */
    function testMaxDeposit() public {
        uint256 cap = 1 ether;

        _setCap(allMarkets[0], cap);

        IERC4626[] memory supplyQueue = new IERC4626[](1);
        supplyQueue[0] = allMarkets[0];

        vm.prank(ALLOCATOR);
        vault.setSupplyQueue(supplyQueue);

        vm.prank(SUPPLIER);
        allMarkets[0].deposit(1 ether, SUPPLIER);

        vm.startPrank(BORROWER);
        silo0.deposit(2 ether, BORROWER);
        silo1.borrow(1 ether, BORROWER, BORROWER);
        vm.stopPrank();

        _forward(1_000);

        uint256 vaultDepositAmount = 0.65 ether;

        vm.prank(SUPPLIER);
        vault.deposit(vaultDepositAmount, ONBEHALF);

        assertEq(vault.maxDeposit(SUPPLIER), cap - vaultDepositAmount, "maxDeposit should be 0");
    }

    function onFlashLoan(address, address, uint256, uint256, bytes calldata) external view returns (bytes32) {
        // this is where silo implementation differs, on silo flashloan state of silo does not change
        // so liquidity stays the same (however not correct during flashloan)
        assertGe(vault.maxWithdraw(ONBEHALF), MIN_TEST_ASSETS, "onFlashLoan assertion MIN_TEST_ASSETS");
        assertLe(vault.maxWithdraw(ONBEHALF), MAX_TEST_ASSETS, "onFlashLoan assertion MAX_TEST_ASSETS");

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}
