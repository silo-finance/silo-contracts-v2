// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

import {TokenMock} from "silo-core/test/foundry/_mocks/TokenMock.sol";
import {SiloFixture_ETH_USDC} from "../_common/fixtures/SiloFixture_ETH_USDC.sol";

/*
    forge test -vv --mc BorrowTest
*/
contract BorrowTest is IntegrationTest {
    uint256 internal constant _BASIS_POINTS = 1e4;
    uint256 internal constant _FORKING_BLOCK_NUMBER = 17336000;

    ISiloConfig siloConfig;
    ISilo silo0;
    ISilo silo1;

    TokenMock token0;
    TokenMock token1;


    function setUp() public {
        vm.createSelectFork(getChainRpcUrl(MAINNET_ALIAS), _FORKING_BLOCK_NUMBER);

        SiloFixture_ETH_USDC siloFixture = new SiloFixture_ETH_USDC();
        (siloConfig, silo0, silo1, token0, token1) = siloFixture.deploy(vm);

        assertTrue(siloConfig.getConfig(address(silo0)).borrowable, "we need borrow to be allowed");
    }

    /*
    forge test -vv --mt test_borrow_zeros
    */
    function test_borrow_zeros() public {
        vm.expectRevert("ERC20: approve from the zero address");
        silo0.borrow(0, address(0), address(0));
    }

    /*
    forge test -vv --mt test_borrow_zero_assets
    */
    function test_borrow_zero_assets() public {
        uint256 assets = 0;
        address borrower = address(1);

        assertEq(silo0.total(ISilo.AssetType.Debt), 0);
        silo0.borrow(assets, borrower, borrower);
        assertEq(silo0.total(ISilo.AssetType.Debt), 0, "expect no change");

        (,, address debtShareToken) = siloConfig.getShareTokens(address(silo0));
        assertEq(IShareToken(debtShareToken).balanceOf(borrower), 0, "expect no debt");
    }

    /*
    forge test -vv --mt test_borrow_when_NotEnoughLiquidity
    */
    function test_borrow_when_NotEnoughLiquidity() public {
        uint256 assets = 1e18;
        address receiver = address(10);

        vm.expectRevert(ISilo.NotEnoughLiquidity.selector);
        silo0.borrow(assets, receiver, receiver);
    }

    /*
    forge test -vv --mt test_borrow_when_BorrowNotPossible_withCollateral
    */
    function test_borrow_when_BorrowNotPossible_withCollateral() public {
        uint256 assets = 1e18;
        address receiver = address(10);

        token0.transferFromMock(address(this), address(silo0), assets);
        silo0.deposit(assets, receiver, ISilo.AssetType.Collateral);

        vm.expectRevert(ISilo.BorrowNotPossible.selector);
        silo0.borrow(assets, receiver, receiver);
    }

    /*
    forge test -vv --mt test_borrow_when_BorrowNotPossible_withProtected
    */
    function test_borrow_when_BorrowNotPossible_withProtected() public {
        uint256 assets = 1e18;
        address receiver = address(10);

        token0.transferFromMock(address(this), address(silo0), assets);
        silo0.deposit(assets, receiver, ISilo.AssetType.Protected);

        vm.expectRevert(ISilo.BorrowNotPossible.selector);
        silo0.borrow(assets, receiver, receiver);
    }

    /*
    forge test -vv --mt test_borrow_pass
    */
    function test_borrow_pass() public {
        uint256 depositAssets = 1e18;
        address borrower = address(0x22334455);
        address depositor = address(0x9876123);

        token0.transferFromMock(depositor, address(silo0), depositAssets);
        vm.prank(depositor);
        silo0.deposit(depositAssets, depositor, ISilo.AssetType.Collateral);

        token1.transferFromMock(address(this), address(silo1), depositAssets);
        silo1.deposit(depositAssets, borrower, ISilo.AssetType.Collateral);

        (address protectedShareToken, address collateralShareToken, address debtShareToken) = siloConfig.getShareTokens(address(silo1));
        assertGt(IShareToken(collateralShareToken).balanceOf(borrower), 0, "expect borrower to have collateral");

        uint256 maxBorrow = silo0.maxBorrow(borrower);
        assertEq(maxBorrow, 0.85e18, "");
        // emit log_named_decimal_uint("maxBorrow", maxBorrow, 18);

        // increasing max amount by 2bp, 1bp might be not enough because of precision error
        uint256 borrowToMuch = maxBorrow + maxBorrow / _BASIS_POINTS * 2;
        // emit log_named_decimal_uint("borrowToMuch", borrowToMuch, 18);

        token0.transferFromMock(address(silo0), address(borrower), borrowToMuch);

        vm.expectRevert(ISilo.AboveMaxLtv.selector);
        vm.prank(borrower);
        silo0.borrow(borrowToMuch, borrower, borrower);

        token0.transferFromMock(address(silo0), address(borrower), maxBorrow);

        uint256 gasStart = gasleft();
        vm.prank(borrower);
        silo0.borrow(maxBorrow, borrower, borrower);
        uint256 gasEnd = gasleft();

        assertEq(gasStart - gasEnd, 128964, "optimise borrow");

        assertEq(IShareToken(debtShareToken).balanceOf(borrower), 0, "expect borrower to NOT have debt in collateral silo");
        assertEq(silo1.total(ISilo.AssetType.Debt), 0, "expect collateral silo to NOT have debt");

        (protectedShareToken, collateralShareToken, debtShareToken) = siloConfig.getShareTokens(address(silo0));
        assertEq(IShareToken(debtShareToken).balanceOf(borrower), maxBorrow, "expect borrower to have debt in debt silo");
        assertEq(silo0.total(ISilo.AssetType.Debt), maxBorrow, "expect debt silo to have debt");
    }

    /*
    forge test -vv --mt test_borrow_twice
    */
    function test_borrow_twice() public {
        uint256 depositAssets = 1e18;
        address borrower = address(0x22334455);
        address depositor = address(0x9876123);

        token1.transferFromMock(address(this), address(silo1), depositAssets);
        silo1.deposit(depositAssets, borrower, ISilo.AssetType.Collateral);

        (address protectedShareToken, address collateralShareToken, address debtShareToken) = siloConfig.getShareTokens(address(silo1));
        assertGt(IShareToken(collateralShareToken).balanceOf(borrower), 0, "expect borrower to have collateral");

        uint256 maxBorrow = silo0.maxBorrow(borrower);
        // emit log_named_decimal_uint("maxBorrow #1", maxBorrow, 18);
        assertEq(maxBorrow, 0.85e18, "maxBorrow borrower can do");

        // deposit, so we can borrow
        token0.transferFromMock(depositor, address(silo0), maxBorrow);
        vm.prank(depositor);
        silo0.deposit(maxBorrow, depositor, ISilo.AssetType.Collateral);

        uint256 borrowAmount = maxBorrow / 2;
        // emit log_named_decimal_uint("borrowAmount", borrowAmount, 18);

        token0.transferFromMock(address(silo0), address(borrower), borrowAmount);

        uint256 gasStart = gasleft();
        vm.prank(borrower);
        uint256 gotShares = silo0.borrow(borrowAmount, borrower, borrower);
        uint256 gasEnd = gasleft();

        assertEq(gasStart - gasEnd, 128973, "optimise borrow #1");

        assertEq(IShareToken(debtShareToken).balanceOf(borrower), 0, "collateral silo: expect borrower to NOT have debt");
        assertEq(IShareToken(collateralShareToken).balanceOf(borrower), 1e18, "collateral silo: borrower has collateral");
        assertEq(silo1.total(ISilo.AssetType.Debt), 0, "collateral silo: NO debt");

        (protectedShareToken, collateralShareToken, debtShareToken) = siloConfig.getShareTokens(address(silo0));
        assertEq(IShareToken(debtShareToken).balanceOf(borrower), 0.425e18, "debt silo: borrower has debt");
        assertEq(gotShares, 0.425e18, "got debt shares");
        assertEq(silo0.total(ISilo.AssetType.Debt), borrowAmount, "debt silo: has debt");

        borrowAmount = silo0.maxBorrow(borrower);
        // emit log_named_decimal_uint("borrowAmount #2", borrowAmount, 18);
        assertEq(borrowAmount, 0.85e18 / 2, "~");

        gasStart = gasleft();
        vm.prank(borrower);
        gotShares = silo0.borrow(borrowAmount, borrower, borrower);
        gasEnd = gasleft();

        assertEq(gasStart - gasEnd, 54860, "optimise borrow #2");

        assertEq(IShareToken(debtShareToken).balanceOf(borrower), 0.85e18, "debt silo: borrower has debt");
        assertEq(gotShares, 0.425e18, "got shares");
        assertEq(silo0.total(ISilo.AssetType.Debt), maxBorrow, "debt silo: has debt");

        (protectedShareToken, collateralShareToken, debtShareToken) = siloConfig.getShareTokens(address(silo1));
        assertEq(IShareToken(debtShareToken).balanceOf(borrower), 0, "collateral silo: expect borrower to NOT have debt");
        assertEq(IShareToken(collateralShareToken).balanceOf(borrower), 1e18, "collateral silo: borrower has collateral");
        assertEq(silo1.total(ISilo.AssetType.Debt), 0, "collateral silo: NO debt");

        assertTrue(silo0.isSolvent(borrower), "still isSolvent");
        assertTrue(silo1.isSolvent(borrower), "still isSolvent");
    }

    /*
    forge test -vv --mt test_borrow_scenarios
    */
    function test_borrow_scenarios() public {
        uint256 depositAssets = 1e18;
        address borrower = address(0x22334455);
        address depositor = address(0x9876123);

        token1.transferFromMock(address(this), address(silo1), depositAssets);
        silo1.deposit(depositAssets, borrower, ISilo.AssetType.Collateral);

        uint256 maxBorrow = silo0.maxBorrow(borrower);

        // deposit, so we can borrow
        token0.transferFromMock(depositor, address(silo0), 100e18);
        vm.prank(depositor);
        silo0.deposit(100e18, depositor, ISilo.AssetType.Collateral);

        _borrow(borrower, 200e18, ISilo.NotEnoughLiquidity.selector);
        _borrow(borrower, maxBorrow * 2, ISilo.AboveMaxLtv.selector);
        _borrow(borrower, maxBorrow / 2);

        _borrow(borrower, 200e18, ISilo.NotEnoughLiquidity.selector);
        _borrow(borrower, maxBorrow, ISilo.AboveMaxLtv.selector);
        _borrow(borrower, maxBorrow / 2);

        assertEq(silo0.maxBorrow(borrower), 0, "maxBorrow 0");
        assertTrue(silo0.isSolvent(borrower), "still isSolvent");
        assertTrue(silo1.isSolvent(borrower), "still isSolvent");

        // still be able to borrow value of "precision error"
        _borrow(borrower, 1e14 - 1);
        _borrow(borrower, 1, ISilo.AboveMaxLtv.selector);
    }

    function _borrow(address _borrower, uint256 _amount) internal returns (uint256 shares) {
        token0.transferFromMock(address(silo0), address(_borrower), _amount);
        vm.prank(_borrower);
        shares = silo0.borrow(_amount, _borrower, _borrower);
    }

    function _borrow(address _borrower, uint256 _amount, bytes4 _revert) internal returns (uint256 shares) {
        token0.transferFromMock(address(silo0), address(_borrower), _amount);
        vm.expectRevert(_revert);
        vm.prank(_borrower);
        shares = silo0.borrow(_amount, _borrower, _borrower);
    }
}
