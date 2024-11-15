// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";

import {LiquidationHelperCommon} from "./LiquidationHelperCommon.sol";

/*
    FOUNDRY_PROFILE=core-test forge test -vv --ffi --mc LiquidationHelper2TokensTest
*/
contract LiquidationHelper2TokensTest is LiquidationHelperCommon {
    function setUp() public {
        vm.label(BORROWER, "BORROWER");
        siloConfig = _setUpLocalFixture();

        _depositForBorrow(DEBT, makeAddr("depositor"));
        _depositCollateral(COLLATERAL, BORROWER, TWO_ASSETS);
        _borrow(DEBT, BORROWER, TWO_ASSETS);

        ISiloConfig.ConfigData memory silo1Config = siloConfig.getConfig(address(silo1));

        assertEq(silo1Config.liquidationFee, 0.025e18, "liquidationFee1");

        liquidationData.user = BORROWER;
        liquidationData.hook = partialLiquidation;
        liquidationData.collateralAsset = address(token0);

        (
            liquidationData.protectedShareToken, liquidationData.collateralShareToken,
        ) = siloConfig.getShareTokens(address(silo1));

        _flashLoanFrom = silo1;
        _debtAsset = address(token1);
    }

    /*
    forge test --ffi --mt test_executeLiquidation_2_tokens -vvv
    */
    function test_executeLiquidation_2_tokens(uint32 _addTimestamp) public {
        vm.assume(_addTimestamp < 365 days);

        vm.warp(block.timestamp + _addTimestamp);

        (, uint256 debtToRepay,) = partialLiquidation.maxLiquidation(BORROWER);

        vm.assume(debtToRepay != 0);
        // for flashloan, so we do not change the silo state
        token1.mint(address(silo1), debtToRepay);

        // this is to mock swap
        token1.mint(address(LIQUIDATION_HELPER), debtToRepay + silo1.flashFee(address(token1), debtToRepay));

        _executeLiquidation(debtToRepay);

        _assertContractDoNotHaveTokens(address(LIQUIDATION_HELPER));
        _assertReceiverNotHaveSTokens(silo0);
        _assertReceiverNotHaveSTokens(silo1);
    }
}
