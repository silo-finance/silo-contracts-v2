// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {LiquidationHelper} from "silo-core/contracts/utils/liquidationHelper/LiquidationHelper.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IPartialLiquidation} from "silo-core/contracts/interfaces/IPartialLiquidation.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IInterestRateModel} from "silo-core/contracts/interfaces/IInterestRateModel.sol";
import {ILiquidationHelper} from "silo-core/contracts/interfaces/ILiquidationHelper.sol";
import {SiloMathLib} from "silo-core/contracts/lib/SiloMathLib.sol";

import {DexSwapMock} from "../../../_mocks/DexSwapMock.sol";
import {SiloLittleHelper} from "../../../_common/SiloLittleHelper.sol";

/*
    FOUNDRY_PROFILE=core-test forge test -vv --ffi --mc LiquidationHelper1TokenTest
*/
contract LiquidationHelper1TokenTest is SiloLittleHelper, Test  {
    address payable public constant TOKENS_RECEIVER = payable(address(123));
    address constant BORROWER = address(0x123);
    uint256 constant COLLATERAL = 10e18;
    uint256 constant DEBT = 7.5e18;
    bool constant SAME_TOKEN = true;

    LiquidationHelper immutable LIQUIDATION_HELPER;

    ISiloConfig siloConfig;

    ILiquidationHelper.LiquidationData liquidationData;
    // TODO write at least one tests with swap
    LiquidationHelper.DexSwapInput[] dexSwapInput;

    ISilo _flashLoanFrom;
    address _debtAsset;

    constructor() {
        LIQUIDATION_HELPER = new LiquidationHelper(makeAddr("nativeToken"), makeAddr("DEXSWAP"), TOKENS_RECEIVER);
    }

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
    function test_executeLiquidation_1_token(uint32 _addTimestamp) public {
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
        _assertReceiverNotHaveSTokens();
    }

    /*
    forge test --ffi --mt test_executeLiquidation_1_sToken -vvv
    */
    function test_executeLiquidation_1_sToken(uint32 _addTimestamp) public {
        vm.assume(_addTimestamp < 365 days);

        vm.warp(block.timestamp + _addTimestamp);

        (, uint256 debtToRepay,) = partialLiquidation.maxLiquidation(BORROWER);

        vm.assume(debtToRepay != 0);
        liquidationData.receiveSToken = true;

        // for flashloan, so we do not change the silo state
        token1.mint(address(silo1), debtToRepay);

        // this is to mock swap
        token1.mint(address(LIQUIDATION_HELPER), debtToRepay + silo1.flashFee(address(token1), debtToRepay));

        _executeLiquidation(debtToRepay);

        _assertReceiverHasSTokens();
        _assertContractDoNotHaveTokens(address(LIQUIDATION_HELPER));
    }

    function _executeLiquidation(
        uint256 _maxDebtToCover
    ) internal returns (uint256 withdrawCollateral, uint256 repayDebtAssets) {
        return LIQUIDATION_HELPER.executeLiquidation(_flashLoanFrom, _debtAsset, _maxDebtToCover, liquidationData, dexSwapInput);
    }

    function _assertContractDoNotHaveTokens(address _contract) internal view {
        assertEq(token1.balanceOf(_contract), 0);
        assertEq(token1.balanceOf(_contract), 0);

        ISiloConfig.ConfigData memory silo0Config = siloConfig.getConfig(address(silo1));
        ISiloConfig.ConfigData memory silo1Config = siloConfig.getConfig(address(silo1));

        assertEq(IShareToken(silo0Config.collateralShareToken).balanceOf(_contract), 0);
        assertEq(IShareToken(silo0Config.protectedShareToken).balanceOf(_contract), 0);
        assertEq(IShareToken(silo0Config.debtShareToken).balanceOf(_contract), 0);

        assertEq(IShareToken(silo1Config.collateralShareToken).balanceOf(_contract), 0);
        assertEq(IShareToken(silo1Config.protectedShareToken).balanceOf(_contract), 0);
        assertEq(IShareToken(silo1Config.debtShareToken).balanceOf(_contract), 0);
    }

    function _assertReceiverHasSTokens() internal view {
        (address protectedShareToken, address collateralShareToken,) = siloConfig.getShareTokens(address(silo1));

        uint256 pBalance = IERC20(protectedShareToken).balanceOf(LIQUIDATION_HELPER.TOKENS_RECEIVER());
        uint256 cBalance = IERC20(collateralShareToken).balanceOf(LIQUIDATION_HELPER.TOKENS_RECEIVER());

        assertGt(pBalance + cBalance, 0, "expect TOKENS_RECEIVER has sTokens");
    }

    function _assertReceiverNotHaveSTokens() internal view {
        (address protectedShareToken, address collateralShareToken,) = siloConfig.getShareTokens(address(silo1));

        uint256 pBalance = IERC20(protectedShareToken).balanceOf(LIQUIDATION_HELPER.TOKENS_RECEIVER());
        uint256 cBalance = IERC20(collateralShareToken).balanceOf(LIQUIDATION_HELPER.TOKENS_RECEIVER());

        assertEq(pBalance + cBalance, 0, "expect TOKENS_RECEIVER has NO sTokens");
    }
}
