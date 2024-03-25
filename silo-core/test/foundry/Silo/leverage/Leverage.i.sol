// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";

import {MintableToken} from "../../_common/MintableToken.sol";
import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";
import {LeverageBorrower, ILeverageBorrower} from "../../_common/LeverageBorrower.sol";

/*
    forge test -vv --ffi --mc LeverageTest
*/
contract LeverageTest is SiloLittleHelper, Test {
    using SiloLensLib for ISilo;

    ISiloConfig siloConfig;
    bool sameToken;

    function setUp() public {
        siloConfig = _setUpLocalFixture("ETH-USDC_UniswapV3_Silo");

        assertTrue(siloConfig.getConfig(address(silo0)).maxLtv != 0, "we need borrow to be allowed");
    }

    /*
    forge test -vv --ffi --mt test_leverage_all_zeros
    */
    function test_leverage_all_zeros() public {
        vm.expectRevert(ISilo.ZeroAssets.selector);
        silo0.leverage(0, ILeverageBorrower(address(0)), address(0), false, bytes(""));
    }

    /*
    forge test -vv --ffi --mt test_leverage_zero_assets
    */
    function test_leverage_zero_assets() public {
        uint256 assets = 0;
        ILeverageBorrower leverageBorrower = ILeverageBorrower(makeAddr("leverageBorrower"));
        address borrower = makeAddr("borrower");

        vm.expectRevert(ISilo.ZeroAssets.selector);
        silo0.leverage(assets, leverageBorrower, borrower, sameToken, bytes(""));
    }

    /*
    forge test -vv --ffi --mt test_leverage_when_NotEnoughLiquidity
    */
    function test_leverage_when_NotEnoughLiquidity() public {
        uint256 assets = 1e18;
        ILeverageBorrower leverageBorrower = ILeverageBorrower(makeAddr("leverageBorrower"));
        address borrower = makeAddr("borrower");

        vm.expectRevert(ISilo.NotEnoughLiquidity.selector);
        silo0.leverage(assets, leverageBorrower, borrower, sameToken, bytes(""));
    }

    /*
    forge test -vv --ffi --mt test_leverage_when_BorrowNotPossible_withCollateral
    */
    function test_leverage_when_BorrowNotPossible_withCollateral() public {
        uint256 assets = 1e18;
        ILeverageBorrower leverageBorrower = ILeverageBorrower(makeAddr("leverageBorrower"));
        address borrower = makeAddr("borrower");

        _deposit(assets, borrower, ISilo.AssetType.Collateral);

        vm.expectCall(address(token0), abi.encodeWithSelector(IERC20.transfer.selector, borrower, assets));

        vm.expectRevert(ISilo.NotEnoughLiquidity.selector); // because we borrow first
        silo0.leverage(assets, leverageBorrower, borrower, sameToken, bytes(""));
    }

    /*
    forge test -vv --ffi --mt test_leverage_when_BorrowNotPossible_withProtected
    */
    function test_leverage_when_BorrowNotPossible_withProtected() public {
        uint256 assets = 1e18;
        ILeverageBorrower leverageBorrower = ILeverageBorrower(makeAddr("leverageBorrower"));
        address borrower = makeAddr("borrower");

        _deposit(assets, borrower, ISilo.AssetType.Protected);

        vm.expectCall(address(token0), abi.encodeWithSelector(IERC20.transfer.selector, borrower, assets));

        vm.expectRevert(ISilo.NotEnoughLiquidity.selector); // because we borrow first
        silo0.leverage(assets, leverageBorrower, borrower, sameToken, bytes(""));
    }

    /*
    forge test -vv --ffi --mt test_leverage_pass
    */
    function test_leverage_pass() public {
        uint256 depositAssets = 1e18;
        uint256 borrowAssets = 0.85e18;
        ILeverageBorrower leverageBorrower = ILeverageBorrower(new LeverageBorrower());
        address borrower = makeAddr("borrower");
        address depositor = makeAddr("depositor");

        _deposit(borrowAssets * 10, depositor, ISilo.AssetType.Collateral);
        token1.mint(address(leverageBorrower), depositAssets);

        bytes memory data = abi.encode(address(silo1), address(token1), depositAssets);

        uint256 borrowToMuch = borrowAssets + 1;

        vm.expectRevert(ISilo.AboveMaxLtv.selector);
        vm.prank(borrower);
        silo0.leverage(borrowToMuch, leverageBorrower, borrower, sameToken, data);

        vm.prank(borrower);
        silo0.leverage(borrowAssets, leverageBorrower, borrower, sameToken, data);

        (address protectedShareToken, address collateralShareToken, address debtShareToken) =
            siloConfig.getShareTokens(address(silo1));
        assertGt(IShareToken(collateralShareToken).balanceOf(borrower), 0, "expect borrower to have collateral");

        assertEq(
            IShareToken(debtShareToken).balanceOf(borrower), 0, "expect borrower to NOT have debt in collateral silo"
        );
        assertEq(silo1.getDebtAssets(), 0, "expect collateral silo to NOT have debt");

        (protectedShareToken, collateralShareToken, debtShareToken) = siloConfig.getShareTokens(address(silo0));
        assertEq(
            IShareToken(debtShareToken).balanceOf(borrower), borrowAssets, "expect borrower to have debt in debt silo"
        );
        assertEq(silo0.getDebtAssets(), borrowAssets, "expect debt silo to have debt");
        assertTrue(silo0.isSolvent(borrower), "still isSolvent");
        assertTrue(silo1.isSolvent(borrower), "still isSolvent");
    }

    /*
    forge test -vv --ffi --mt test_leverage_twice
    */
    function test_leverage_twice() public {
        uint256 depositAssets = 1e18;
        uint256 borrowAssets = 0.85e18;
        ILeverageBorrower leverageBorrower = ILeverageBorrower(new LeverageBorrower());
        address borrower = makeAddr("borrower");
        address depositor = makeAddr("depositor");

        _deposit(borrowAssets, depositor, ISilo.AssetType.Collateral);
        token1.mint(address(leverageBorrower), depositAssets);

        uint256 maxBorrow = silo0.maxBorrow(borrower, sameToken);
        assertEq(maxBorrow, 0, "maxBorrow should be 0 because this is where collateral is");

        bytes memory data = abi.encode(address(silo1), address(token1), depositAssets);

        vm.prank(borrower);
        silo0.leverage(borrowAssets, leverageBorrower, borrower, sameToken, data);

        (,, address debtShareToken) = siloConfig.getShareTokens(address(silo0));
        assertEq(IShareToken(debtShareToken).balanceOf(borrower), borrowAssets, "expect borrower to have 1/2 of debt");

        (, address collateralShareToken,) = siloConfig.getShareTokens(address(silo1));
        assertEq(
            IShareToken(collateralShareToken).balanceOf(borrower),
            depositAssets,
            "collateral silo: borrower has collateral"
        );
        assertEq(silo0.getDebtAssets(), borrowAssets, "silo debt");

        token1.mint(address(leverageBorrower), depositAssets);

        vm.expectRevert(ISilo.NotEnoughLiquidity.selector);
        vm.prank(borrower);
        silo0.leverage(borrowAssets, leverageBorrower, borrower, sameToken, data);

        _deposit(borrowAssets, depositor, ISilo.AssetType.Collateral);

        vm.prank(borrower);
        silo0.leverage(borrowAssets, leverageBorrower, borrower, sameToken, data);

        assertEq(IShareToken(debtShareToken).balanceOf(borrower), borrowAssets * 2, "debt silo: borrower has debt");
        assertEq(silo0.getDebtAssets(), borrowAssets * 2, "debt silo: has debt");

        // collateral silo
        (, collateralShareToken, debtShareToken) = siloConfig.getShareTokens(address(silo1));
        assertEq(
            IShareToken(debtShareToken).balanceOf(borrower), 0, "collateral silo: expect borrower to NOT have debt"
        );
        assertEq(
            IShareToken(collateralShareToken).balanceOf(borrower),
            depositAssets * 2,
            "collateral silo: borrower has collateral"
        );
        assertEq(silo1.getDebtAssets(), 0, "collateral silo: NO debt");

        assertTrue(silo0.isSolvent(borrower), "still isSolvent");
        assertTrue(silo1.isSolvent(borrower), "still isSolvent");
    }
}
