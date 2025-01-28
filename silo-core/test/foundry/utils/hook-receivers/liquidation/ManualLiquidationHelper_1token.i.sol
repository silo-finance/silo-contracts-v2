// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";

import {ManualLiquidationHelperCommon} from "./ManualLiquidationHelperCommon.sol";

/*
    FOUNDRY_PROFILE=core-test forge test -vv --ffi --mc ManualLiquidationHelper1TokenTest
*/
contract ManualLiquidationHelper1TokenTest is ManualLiquidationHelperCommon {
    uint256 constant LIQUIDATION_UNDERESTIMATION = 1;

    function setUp() public {
        vm.label(BORROWER, "BORROWER");
        siloConfig = _setUpLocalFixture();

        _depositCollateral(COLLATERAL, BORROWER, SAME_ASSET);
        _borrow(DEBT, BORROWER, SAME_ASSET);

        ISiloConfig.ConfigData memory collateralConfig = siloConfig.getConfig(address(silo1));

        assertEq(collateralConfig.liquidationFee, 0.025e18, "liquidationFee");

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

        // for flashloan, so we do not change the silo state and be able to provide tokens for repay
        // token1.mint(address(silo1), debtToRepay);

        emit log_named_decimal_uint("collateralToLiquidate", collateralToLiquidate, 18);
        emit log_named_decimal_uint("          debtToRepay", debtToRepay, 18);

        // we reject cases with invalid config or not profitable
        vm.assume(collateralToLiquidate >= debtToRepay);

        token1.mint(address(this), debtToRepay);
        token1.approve(address(LIQUIDATION_HELPER), debtToRepay);

        assertEq(token1.balanceOf(TOKENS_RECEIVER), 0, "no token1 before liquidation");

        _executeLiquidation();

        uint256 withdrawCollateral = token1.balanceOf(TOKENS_RECEIVER);

        assertEq(
            collateralToLiquidate,
            withdrawCollateral - LIQUIDATION_UNDERESTIMATION,
            "collateralToLiquidate == withdrawCollateral"
        );

        _assertAddressDoesNotHaveTokens(address(LIQUIDATION_HELPER));
        _assertAddressHasNoSTokens(silo0, TOKENS_RECEIVER);
        _assertAddressHasNoSTokens(silo1, TOKENS_RECEIVER);
    }
}
