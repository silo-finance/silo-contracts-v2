// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";

import {IERC20R} from "silo-core/contracts/interfaces/IERC20R.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IZeroExSwapModule} from "silo-core/contracts/interfaces/IZeroExSwapModule.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ILeverageUsingSiloWithZeroEx} from "silo-core/contracts/interfaces/ILeverageUsingSiloWithZeroEx.sol";
import {LeverageUsingSiloWithZeroEx} from "silo-core/contracts/leverage/LeverageUsingSiloWithZeroEx.sol";

import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";
import {SwapRouterMock} from "./mocks/SwapRouterMock.sol";

import {MintableToken} from "../_common/MintableToken.sol";
import {SiloFixture, SiloConfigOverride} from "../_common/fixtures/SiloFixture.sol";

/*
    FOUNDRY_PROFILE=core_test  forge test -vv --ffi --mc LeverageUsingSiloWithZeroExTest

TODO triple check approvals
*/
contract LeverageUsingSiloWithZeroExTest is SiloLittleHelper, Test {
    using SafeERC20 for IERC20;

    uint256 constant _PRECISION = 1e18;

    ISiloConfig cfg;
    LeverageUsingSiloWithZeroEx siloLeverage;
    address collateralShareToken;
    address debtShareToken;
    SwapRouterMock swap;

    function setUp() public {
        cfg = _setUpLocalFixture();

        _deposit(1e18, address(1));
        _depositForBorrow(1e18, address(2));

        (,collateralShareToken,) = cfg.getShareTokens(address(silo0));
        (,, debtShareToken) = cfg.getShareTokens(address(silo1));

        siloLeverage = new LeverageUsingSiloWithZeroEx(address(this));
        siloLeverage.setRevenueReceiver(makeAddr("RevenueReceiver"));
        siloLeverage.setLeverageFee(0.0001e18);

        swap = new SwapRouterMock();

        token0.setOnDemand(false);
        token1.setOnDemand(false);
    }

    /*
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_leverage_alwaysRevert_InvalidFlashloanLender
    */
    function test_leverage_alwaysRevert_InvalidFlashloanLender(address _caller) public {
        vm.prank(_caller);
        vm.expectRevert(ILeverageUsingSiloWithZeroEx.InvalidFlashloanLender.selector);

        siloLeverage.onFlashLoan({
            _initiator: address(0),
            _borrowToken: address(0),
            _flashloanAmount: 0,
            _flashloanFee: 0,
            _data: ""
        });
    }

    /*
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_leverage_example_noInterest
    */
    function test_leverage_example_noInterest() public {
        _openLeverageExample();
        _closeLeverageExample();
    }

    /*
    Leverage contract should never have any tokens

    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_leverage_example
    */


    /*
    close should repay all debt (if position solvent?)

    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_leverage_example
    */

    /*
    accrue interest then close

    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_leverage_example_withInterest_solvent
    */
    function test_leverage_example_withInterest_solvent() public {
        address user = makeAddr("user");

        _openLeverageExample();

        uint256 totalAssetsBefore = silo1.totalAssets();

        vm.warp(block.timestamp + 2000 days);

        uint256 totalAssetsAfter = silo1.totalAssets();
        assertGt(totalAssetsAfter, totalAssetsBefore * 1005 / 1000, "expect at least 0.5% generated interest");

        assertTrue(silo1.isSolvent(user), "we want example with solvent user");

        _closeLeverageExample();
    }

    /*
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_leverage_example_withInterest_inSolvent
    */
    function test_leverage_example_withInterest_inSolvent() public {
        address user = makeAddr("user");

        _openLeverageExample();

        vm.startPrank(user);
        silo0.withdraw(silo0.maxWithdraw(user), user, user);

        vm.warp(block.timestamp + 1000 days);

        assertLt(siloLens.getUserLTV(silo1, user), 0.90e18, "we want case when there is no bad debt");
        assertFalse(silo1.isSolvent(user), "we want example with inSolvent user");

        _closeLeverageExample();
    }

    /*
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_leverage_anySiloForFlashloan
    */
    function test_leverage_anySiloForFlashloan() public {
        // SEPARATE SILO FOR FLASHLOAN

        SiloFixture siloFixture = new SiloFixture();

        MintableToken tokenA = new MintableToken(18);

        SiloConfigOverride memory overrides;
        overrides.token0 = address(tokenA);
        overrides.token1 = address(token1);
        overrides.configName = "Silo_Local_noOracle";

        (, , ISilo siloFlashloan,,,) = siloFixture.deploy_local(overrides);

        vm.label(address(siloFlashloan), "siloFlashloan");

        token1.mint(address(this), 5e18);
        token1.approve(address(siloFlashloan), 5e18);
        siloFlashloan.deposit(5e18, address(this));

        // OPEN

        address user = makeAddr("user");
        uint256 depositAmount = 0.1e18;
        uint256 multiplier = 1.08e18;

        (
            ILeverageUsingSiloWithZeroEx.FlashArgs memory flashArgs,
            ILeverageUsingSiloWithZeroEx.DepositArgs memory depositArgs,
            IZeroExSwapModule.SwapArgs memory swapArgs
        ) = _defaultOpenArgs(depositAmount, multiplier, address(siloFlashloan));

        (uint256 totalDeposited, ) = _openLeverage(user, flashArgs, depositArgs, swapArgs);

        assertGt(silo1.maxRepay(user), 0, "users has debt");

        uint256 fee = siloFlashloan.flashFee(siloFlashloan.asset(), flashArgs.amount);
        assertGt(fee, 0, "we want setup with some fee");
        assertEq(token1.balanceOf(address(siloFlashloan)), 5e18 + fee, "siloFlashloan got flashloan fees");

        // CLOSE

        ILeverageUsingSiloWithZeroEx.CloseLeverageArgs memory closeArgs;

        (flashArgs, closeArgs, swapArgs) = _defaultCloseArgs(user, address(siloFlashloan));

        _closeLeverage(user, flashArgs, closeArgs, swapArgs);

        _assertUserHasNoPosition(user);
        _assertSiloLeverageHasNoTokens();
        _assertThereIsNoDebtApprovals(user);

        assertGt(token1.balanceOf(address(siloFlashloan)), 5e18 + fee, "siloFlashloan got another flashloan fee");
    }

    function _openLeverageExample() internal {
        address user = makeAddr("user");
        uint256 depositAmount = 0.1e18;
        uint256 multiplier = 1.08e18;

        (
            ILeverageUsingSiloWithZeroEx.FlashArgs memory flashArgs,
            ILeverageUsingSiloWithZeroEx.DepositArgs memory depositArgs,
            IZeroExSwapModule.SwapArgs memory swapArgs
        ) = _defaultOpenArgs(depositAmount, multiplier, address(silo1));

        uint256 swapAmountOut = flashArgs.amount * 99 / 100;
        uint256 leverageFee = siloLeverage.calculateLeverageFee(depositArgs.amount + swapAmountOut);
        uint256 totalDeposit = depositArgs.amount + swapAmountOut - leverageFee;

        (uint256 totalDeposited, ) = _openLeverage(user, flashArgs, depositArgs, swapArgs);

        uint256 finalMultiplier = totalDeposited * _PRECISION / depositArgs.amount;

        assertEq(finalMultiplier, 2.06899308e18, "finalMultiplier");
        assertEq(silo0.previewRedeem(silo0.balanceOf(user)), 0.206899308e18, "users collateral");

        uint256 flashFee = silo1.flashFee(address(token1), flashArgs.amount);

        assertEq(
            silo1.maxRepay(user),
            flashArgs.amount + flashFee,
            "user has debt equal to flashloan + flashloan fee"
        );

        assertEq(silo1.maxRepay(user), 0.10908e18, "users debt");

        _assertSiloLeverageHasNoTokens();
    }

    function _openLeverage(
        address _user,
        ILeverageUsingSiloWithZeroEx.FlashArgs memory _flashArgs,
        ILeverageUsingSiloWithZeroEx.DepositArgs memory _depositArgs,
        IZeroExSwapModule.SwapArgs memory _swapArgs
    ) internal returns (uint256 totalDeposit, uint256 totalBorrow) {
        vm.startPrank(_user);
        token0.mint(_user, _depositArgs.amount);

        // mock the swap: debt token -> collateral token, price is 1:1, lt's mock some fee
        swap.setSwap(_swapArgs.sellToken, _flashArgs.amount, _swapArgs.buyToken, _flashArgs.amount * 99 / 100);

        vm.startPrank(_user);

        // APPROVALS

        // siloLeverage needs approval to pull user tokens to do deposit in behalf of user
        IERC20(_depositArgs.silo.asset()).forceApprove(address(siloLeverage), _depositArgs.amount);

        {
            uint256 debtReceiveApproval = _calculateDebtReceiveApproval(
                _flashArgs.amount, ISilo(_flashArgs.flashloanTarget)
            );

            // user must set receive approval for debt share token
            IERC20R(debtShareToken).setReceiveApproval(address(siloLeverage), debtReceiveApproval);
        }

        {
            uint256 swapAmountOut = _flashArgs.amount * 99 / 100;
            uint256 totalUserDeposit;

            {
                uint256 leverageFee = siloLeverage.calculateLeverageFee(_depositArgs.amount + swapAmountOut);
                totalUserDeposit = _depositArgs.amount + swapAmountOut - leverageFee;
            }

            vm.expectEmit(address(siloLeverage));

            emit ILeverageUsingSiloWithZeroEx.OpenLeverage({
                totalBorrow: _flashArgs.amount + ISilo(_flashArgs.flashloanTarget).flashFee(address(token1), _flashArgs.amount),
                totalDeposit: totalUserDeposit,
                flashloanAmount: _flashArgs.amount,
                swapAmountOut: swapAmountOut,
                borrowerDeposit: _depositArgs.amount,
                borrower: _user
            });
        }

        (totalDeposit, totalBorrow) = siloLeverage.openLeveragePosition(_flashArgs, _swapArgs, _depositArgs);

        vm.stopPrank();

        _assertThereIsNoDebtApprovals(_user);
    }

    function _closeLeverageExample() internal {
        address user = makeAddr("user");

        (
            ILeverageUsingSiloWithZeroEx.FlashArgs memory _flashArgs,
            ILeverageUsingSiloWithZeroEx.CloseLeverageArgs memory _closeArgs,
            IZeroExSwapModule.SwapArgs memory _swapArgs
        ) = _defaultCloseArgs(user, address(silo1));

        _closeLeverage(user, _flashArgs, _closeArgs, _swapArgs);

        assertEq(silo0.balanceOf(user), 0, "user nas NO collateral");
        assertEq(silo1.maxRepay(user), 0, "user has NO debt");

        _assertSiloLeverageHasNoTokens();
    }

    function _closeLeverage(
        address _user,
        ILeverageUsingSiloWithZeroEx.FlashArgs memory _flashArgs,
        ILeverageUsingSiloWithZeroEx.CloseLeverageArgs memory _closeArgs,
        IZeroExSwapModule.SwapArgs memory _swapArgs
    ) internal {
        vm.startPrank(_user);

        // mock the swap: part of collateral token -> debt token, so we can repay flashloan
        // for this test case price is 1:1
        // we need swap bit more, so we can count for fee or slippage, here we simulate +11%
        uint256 amountIn = _flashArgs.amount * 111 / 100;
        swap.setSwap(_swapArgs.sellToken, amountIn, _swapArgs.buyToken, amountIn * 99 / 100);

        // APPROVALS
        uint256 collateralSharesApproval = IERC20(collateralShareToken).balanceOf(_user);
        IERC20(collateralShareToken).forceApprove(address(siloLeverage), collateralSharesApproval);

        vm.expectEmit(address(siloLeverage));

        emit ILeverageUsingSiloWithZeroEx.CloseLeverage({
            depositWithdrawn: silo0.previewRedeem(silo0.balanceOf(_user)),
            swapAmountOut: (_flashArgs.amount * 111 / 100) * 99 / 100,
            flashloanRepay: _flashArgs.amount,
            borrower: _user
        });

        siloLeverage.closeLeveragePosition(_flashArgs, _swapArgs, _closeArgs);

        vm.stopPrank();

        _assertThereIsNoDebtApprovals(_user);
    }

    function _calculateDebtReceiveApproval(
        uint256 _flashAmount,
        ISilo _flashFrom
    ) internal view returns (uint256 debtReceiveApproval) {
        uint256 flashFee = _flashFrom.flashFee(_flashFrom.asset(), _flashAmount);
        debtReceiveApproval = _flashAmount + flashFee;
    }

    // TODO nonReentrant test

    function _defaultOpenArgs(
        uint256 _depositAmount,
        uint256 _multiplier,
        address _flashloanTarget
    )
        internal
        view
        returns(
            ILeverageUsingSiloWithZeroEx.FlashArgs memory flashArgs,
            ILeverageUsingSiloWithZeroEx.DepositArgs memory depositArgs,
            IZeroExSwapModule.SwapArgs memory swapArgs
        )
    {
        flashArgs = ILeverageUsingSiloWithZeroEx.FlashArgs({
            amount: _depositAmount * _multiplier / _PRECISION,
            flashloanTarget: _flashloanTarget
        });

        depositArgs = ILeverageUsingSiloWithZeroEx.DepositArgs({
            amount: _depositAmount,
            collateralType: ISilo.CollateralType.Collateral,
            silo: silo0
        });

        // this data should be provided by BE API
        // NOTICE: user needs to give allowance for swap router to use tokens
        swapArgs = IZeroExSwapModule.SwapArgs({
            buyToken: address(silo0.asset()),
            sellToken: address(silo1.asset()),
            allowanceTarget: address(swap),
            exchangeProxy: address(swap),
            swapCallData: "mocked swap data"
        });
    }

    function _defaultCloseArgs(
        address _borrower,
        address _flashloanTarget
    )
        internal
        view
        returns (
            ILeverageUsingSiloWithZeroEx.FlashArgs memory flashArgs,
            ILeverageUsingSiloWithZeroEx.CloseLeverageArgs memory closeArgs,
            IZeroExSwapModule.SwapArgs memory swapArgs
        )
    {
        flashArgs = ILeverageUsingSiloWithZeroEx.FlashArgs({
            amount: silo1.maxRepay(_borrower),
            flashloanTarget: _flashloanTarget
        });

        closeArgs = ILeverageUsingSiloWithZeroEx.CloseLeverageArgs({
            siloWithCollateral: silo0,
            collateralType: ISilo.CollateralType.Collateral
        });

        swapArgs = IZeroExSwapModule.SwapArgs({
            sellToken: address(silo0.asset()),
            buyToken: address(silo1.asset()),
            allowanceTarget: address(swap),
            exchangeProxy: address(swap),
            swapCallData: "mocked swap data"
        });
    }

    function _assertUserHasNoPosition(address _user) internal view {
        assertEq(silo0.balanceOf(_user), 0, "[_assertUserHasNoPosition] user nas NO collateral");
        assertEq(silo1.balanceOf(_user), 0, "[_assertUserHasNoPosition] user has NO debt balance");
        assertEq(silo1.maxRepay(_user), 0, "[_assertUserHasNoPosition] user has NO debt");
    }

    function _assertThereIsNoDebtApprovals(address _user) internal view {
        assertEq(IERC20R(debtShareToken).receiveAllowance(_user, address(siloLeverage)), 0, "[NoDebtApprovals] for siloLeverage");
        assertEq(IERC20R(debtShareToken).receiveAllowance(_user, address(swap)), 0, "[NoDebtApprovals] for swap");
        assertEq(IERC20R(debtShareToken).receiveAllowance(_user, address(swap)), 0, "[NoDebtApprovals] for swap");
        assertEq(IERC20R(debtShareToken).receiveAllowance(_user, address(silo0)), 0, "[NoDebtApprovals] for silo0");
        assertEq(IERC20R(debtShareToken).receiveAllowance(_user, address(silo1)), 0, "[NoDebtApprovals] for silo1");
    }

    function _assertSiloLeverageHasNoTokens() internal view {
        _assertSiloLeverageHasNoTokens(address(0));
    }

    function _assertSiloLeverageHasNoTokens(address _customToken) internal view {
        assertEq(token0.balanceOf(address(siloLeverage)), 0, "siloLeverage has no  token0");
        assertEq(token1.balanceOf(address(siloLeverage)), 0, "siloLeverage has no  token1");

        if (_customToken != address(0)) {
            assertEq(
                IERC20(_customToken).balanceOf(address(siloLeverage)),
                0,
                "siloLeverage has no custom tokens"
            );
        }
    }
}
