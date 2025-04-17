// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {SiloLens} from "silo-core/contracts/SiloLens.sol";

import {ManualLiquidationHelperCommon} from "./ManualLiquidationHelperCommon.sol";

/*
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mc ManualLiquidationHelper1TokenTest
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
    function test_executeLiquidation_1_token_woBadDebt(
        uint32 _addTimestamp
    ) public {
//        uint32 _addTimestamp = 1478627871;

        vm.warp(block.timestamp + _addTimestamp);

        (uint256 collateralToLiquidate, uint256 debtToRepay,) = partialLiquidation.maxLiquidation(BORROWER);
        // note that price is 1:1
        vm.assume(debtToRepay != 0);
        vm.assume(collateralToLiquidate >= debtToRepay);

        emit log_named_decimal_uint("collateralToLiquidate", collateralToLiquidate, 18);
        emit log_named_decimal_uint("          debtToRepay", debtToRepay, 18);

        token1.mint(address(this), debtToRepay);
        token1.approve(address(LIQUIDATION_HELPER), debtToRepay);

        assertEq(token1.balanceOf(_tokenReceiver()), 0, "no token1 before liquidation");

        _executeLiquidation();

        _assertAddressDoesNotHaveTokens(address(this));
        _assertAddressDoesNotHaveTokens(address(LIQUIDATION_HELPER));

        uint256 withdrawCollateral = token1.balanceOf(_tokenReceiver());

        assertEq(
            withdrawCollateral - LIQUIDATION_UNDERESTIMATION,
            collateralToLiquidate,
            "you should not get less than what was estimated"
        );

        _assertAddressHasNoSTokens(silo0, _tokenReceiver());
        _assertAddressHasNoSTokens(silo1, _tokenReceiver());

        assertTrue(silo0.isSolvent(BORROWER), "borrower must be solvent after manual liquidation");
    }

    /*
    FOUNDRY_PROFILE=core_test forge test  --ffi --mt test_executeLiquidation_1_token_BadDebt -vv
    */
    /// forge-config: core_test.fuzz.runs = 1000
    function test_executeLiquidation_1_token_BadDebt_fuzz(
        uint32 _addTimestamp
    ) public {
        vm.warp(block.timestamp + _addTimestamp);

        uint256 ltv = siloLens.getLtv(silo1, BORROWER);
        vm.assume(ltv > 1e18);
        // for huge LTV estimation for maxLiquidation became invalid
        vm.assume(ltv < 1.31e18);
        emit log_named_decimal_uint("ltv", ltv, 16);

        (uint256 collateralToLiquidate, uint256 debtToRepay,) = partialLiquidation.maxLiquidation(BORROWER);

        emit log_named_decimal_uint("collateralToLiquidate", collateralToLiquidate, 18);
        emit log_named_decimal_uint("          debtToRepay", debtToRepay, 18);

        token1.mint(address(this), debtToRepay);
        token1.approve(address(LIQUIDATION_HELPER), debtToRepay);

        assertEq(token1.balanceOf(_tokenReceiver()), 0, "no token1 before liquidation");

        _executeLiquidation();

        _assertAddressDoesNotHaveTokens(address(this));
        _assertAddressDoesNotHaveTokens(address(LIQUIDATION_HELPER));

        uint256 withdrawCollateral = token1.balanceOf(_tokenReceiver());

        assertGe(
            withdrawCollateral,
            collateralToLiquidate,
            "on bad debt estimation should work as well"
        );

        _assertAddressHasNoSTokens(silo0, _tokenReceiver());
        _assertAddressHasNoSTokens(silo1, _tokenReceiver());

        assertTrue(silo0.isSolvent(BORROWER), "borrower must be solvent after manual liquidation");
    }
}
