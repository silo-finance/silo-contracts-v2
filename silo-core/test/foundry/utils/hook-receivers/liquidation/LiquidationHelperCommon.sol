// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {LiquidationHelper} from "silo-core/contracts/utils/liquidationHelper/LiquidationHelper.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ILiquidationHelper} from "silo-core/contracts/interfaces/ILiquidationHelper.sol";

import {DexSwapMock} from "../../../_mocks/DexSwapMock.sol";
import {SiloLittleHelper} from "../../../_common/SiloLittleHelper.sol";

abstract contract LiquidationHelperCommon is SiloLittleHelper, Test {
    address payable public constant TOKENS_RECEIVER = payable(address(123));
    address constant BORROWER = address(0x123);
    uint256 constant COLLATERAL = 10e18;
    uint256 constant DEBT = 7.5e18;

    LiquidationHelper immutable LIQUIDATION_HELPER;

    ISiloConfig siloConfig;

    ILiquidationHelper.LiquidationData liquidationData;
    // TODO write at least one tests with swap
    LiquidationHelper.DexSwapInput[] dexSwapInput;

    ISilo _flashLoanFrom;
    address _debtAsset;

    constructor() {
        LIQUIDATION_HELPER = new LiquidationHelper(
            makeAddr("nativeToken"), makeAddr("DEXSWAP"), TOKENS_RECEIVER
        );
    }

    function _executeLiquidation(
        uint256 _maxDebtToCover
    ) internal returns (uint256 withdrawCollateral, uint256 repayDebtAssets) {
        return LIQUIDATION_HELPER.executeLiquidation(
            _flashLoanFrom, _debtAsset, _maxDebtToCover, liquidationData, dexSwapInput
        );
    }

    function _assertContractDoNotHaveTokens(address _contract) internal view {
        assertEq(token0.balanceOf(_contract), 0, "token0.balanceOf");
        assertEq(token1.balanceOf(_contract), 0, "token1.balanceOf");

        (
            address protectedShareToken, address collateralShareToken, address debtShareToken
        ) = siloConfig.getShareTokens(address(silo0));

        assertEq(IERC20(collateralShareToken).balanceOf(_contract), 0, "collateralShareToken0");
        assertEq(IERC20(protectedShareToken).balanceOf(_contract), 0, "protectedShareToken0");
        assertEq(IERC20(debtShareToken).balanceOf(_contract), 0, "debtShareToken");

        (
            protectedShareToken, collateralShareToken, debtShareToken
        ) = siloConfig.getShareTokens(address(silo1));

        assertEq(IERC20(collateralShareToken).balanceOf(_contract), 0, "collateralShareToken1");
        assertEq(IERC20(protectedShareToken).balanceOf(_contract), 0, "protectedShareToken1");
        assertEq(IERC20(debtShareToken).balanceOf(_contract), 0, "debtShareToken1");
    }

    function _assertReceiverHasSTokens(ISilo _silo) internal view {
        (address protectedShareToken, address collateralShareToken,) = siloConfig.getShareTokens(address(_silo));

        uint256 pBalance = IERC20(protectedShareToken).balanceOf(LIQUIDATION_HELPER.TOKENS_RECEIVER());
        uint256 cBalance = IERC20(collateralShareToken).balanceOf(LIQUIDATION_HELPER.TOKENS_RECEIVER());

        assertGt(pBalance + cBalance, 0, "expect TOKENS_RECEIVER has sTokens");
    }

    function _assertReceiverNotHaveSTokens(ISilo _silo) internal view {
        (address protectedShareToken, address collateralShareToken,) = siloConfig.getShareTokens(address(_silo));

        uint256 pBalance = IERC20(protectedShareToken).balanceOf(LIQUIDATION_HELPER.TOKENS_RECEIVER());
        uint256 cBalance = IERC20(collateralShareToken).balanceOf(LIQUIDATION_HELPER.TOKENS_RECEIVER());

        assertEq(pBalance + cBalance, 0, "expect TOKENS_RECEIVER has NO sTokens");
    }
}
