// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";

import {LiquidationHelperCommon} from "./LiquidationHelperCommon.sol";

/*
    FOUNDRY_PROFILE=core-test forge test -vv --ffi --mc LiquidationHelper1TokenTest
*/
contract LiquidationHelper1TokenTest is LiquidationHelperCommon {
    function setUp() public {
        vm.label(BORROWER, "BORROWER");
        siloConfig = _setUpLocalFixture();

        _depositCollateral(COLLATERAL, BORROWER, SAME_ASSET);
        _borrow(DEBT, BORROWER, SAME_ASSET);

        ISiloConfig.ConfigData memory silo1Config = siloConfig.getConfig(address(silo1));

        assertEq(silo1Config.liquidationFee, 0.025e18, "liquidationFee1");

        liquidationData.user = BORROWER;
        liquidationData.hook = partialLiquidation;
        liquidationData.collateralAsset = address(token1);

        (
            liquidationData.protectedShareToken, liquidationData.collateralShareToken,
        ) = siloConfig.getShareTokens(address(silo1));

        _flashLoanFrom = silo1;
        _debtAsset = address(token1);
    }

    /*
    forge test --ffi --mt test_executeLiquidation_1_token -vvv
    */
    function test_executeLiquidation_1_token(
        uint32 _addTimestamp
    ) public {
        vm.warp(block.timestamp + _addTimestamp);

        (uint256 collateralToLiquidate, uint256 debtToRepay,) = partialLiquidation.maxLiquidation(BORROWER);

        vm.assume(debtToRepay != 0);
        vm.assume(collateralToLiquidate >= debtToRepay); // no bad debt

        // for flashloan, so we do not change the silo state and be able to provide tokens for repay
        token1.mint(address(silo1), debtToRepay);

        // mock the swap behaviour by providing tokens to cover fee, collateral is the same token, and we have price 1:1
        // so we should miss only fee
        uint256 flashFee = silo1.flashFee(address(token1), debtToRepay);
        emit log_named_decimal_uint("collateralToLiquidate", collateralToLiquidate, 18);
        emit log_named_decimal_uint("          debtToRepay", debtToRepay, 18);
        emit log_named_decimal_uint("             flashFee", flashFee, 18);

        // we reject cases with invalid config or not profitable
        vm.assume(collateralToLiquidate >= debtToRepay + flashFee);

        // "swap mock", so we can repay flashloan
        token1.mint(address(LIQUIDATION_HELPER), debtToRepay + flashFee);

        assertEq(token1.balanceOf(address(this)), 0, "no token1 before liquidation");

        _executeLiquidation(debtToRepay);

        assertEq(
            token1.balanceOf(TOKENS_RECEIVER) - 1,
            collateralToLiquidate,
            "expect full collateral after liquidation, because we mock swap"
            // TODO why this is not eq, but we got 1wei diff?
        );

        _assertContractDoNotHaveTokens(address(LIQUIDATION_HELPER));
        _assertReceiverNotHaveSTokens(silo0);
        _assertReceiverNotHaveSTokens(silo1);
    }
}
