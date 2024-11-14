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
import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";
import {SiloMathLib} from "silo-core/contracts/lib/SiloMathLib.sol";

import {DexSwapMock} from "../../../_mocks/DexSwapMock.sol";
import {SiloLittleHelper} from "../../../_common/SiloLittleHelper.sol";

/*
    FOUNDRY_PROFILE=core-test forge test -vv --ffi --mc LiquidationHelper1TokenTest
*/
contract LiquidationHelper1TokenTest is SiloLittleHelper, Test  {
    address payable public constant TOKENS_RECEIVER = payable(address(123));

    DexSwapMock immutable DEXSWAP;
    LiquidationHelper immutable LIQUIDATION_HELPER;

    using SiloLensLib for ISilo;

    address constant BORROWER = address(0x123);
    uint256 constant COLLATERAL = 10e18;
    uint256 constant COLLATERAL_SHARES = COLLATERAL * SiloMathLib._DECIMALS_OFFSET_POW;
    uint256 constant DEBT = 7.5e18;
    bool constant SAME_TOKEN = true;

    ISiloConfig siloConfig;

    event LiquidationCall(address indexed liquidator, bool receiveSToken);
    error SenderNotSolventAfterTransfer();

    ILiquidationHelper.LiquidationData liquidationData;
    LiquidationHelper.DexSwapInput[] dexSwapInput;

    ISilo _flashLoanFrom;
    address _debtAsset;

    constructor() {
        DEXSWAP = new DexSwapMock();
        LIQUIDATION_HELPER = new LiquidationHelper(makeAddr("nativeToken"), address(DEXSWAP), TOKENS_RECEIVER);
    }

    function setUp() public {
        siloConfig = _setUpLocalFixture();

        vm.prank(BORROWER);
        token0.mint(BORROWER, COLLATERAL);

        vm.prank(BORROWER);
        token0.approve(address(silo0), COLLATERAL);

        vm.prank(BORROWER);
        silo0.deposit(COLLATERAL, BORROWER);

        vm.prank(BORROWER);
        silo0.borrowSameAsset(DEBT, BORROWER, BORROWER);

        assertEq(token0.balanceOf(address(this)), 0, "liquidation should have no collateral");
        assertEq(token0.balanceOf(address(silo0)), COLLATERAL - DEBT, "silo0 has only 2.5 debt token (10 - 7.5)");

        ISiloConfig.ConfigData memory silo0Config = siloConfig.getConfig(address(silo0));

        assertEq(silo0Config.liquidationFee, 0.05e18, "liquidationFee1");

        liquidationData.user = BORROWER;
        liquidationData.hook = partialLiquidation;
        liquidationData.collateralAsset = address(token0);

        (
            liquidationData.protectedShareToken, liquidationData.collateralShareToken,
        ) = siloConfig.getShareTokens(address(silo0));

        _flashLoanFrom = silo0;
        _debtAsset = address(token0);
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
        token0.mint(address(silo0), debtToRepay);

        // this is to mock swap
        token0.mint(address(LIQUIDATION_HELPER), debtToRepay + silo0.flashFee(address(token0), debtToRepay));

        _executeLiquidation(debtToRepay);

        _afterEach();
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
        token0.mint(address(silo0), debtToRepay);

        // this is to mock swap
        token0.mint(address(LIQUIDATION_HELPER), debtToRepay + silo0.flashFee(address(token0), debtToRepay));

        _executeLiquidation(debtToRepay);

        _assertReceiverHasSTokens();

        _afterEach();
    }

    function _executeLiquidation(
        uint256 _maxDebtToCover
    ) internal returns (uint256 withdrawCollateral, uint256 repayDebtAssets) {
        return LIQUIDATION_HELPER.executeLiquidation(_flashLoanFrom, _debtAsset, _maxDebtToCover, liquidationData, dexSwapInput);
    }

    function _afterEach() internal view {
        _assertContractDoNotHaveTokens(address(LIQUIDATION_HELPER));
    }

    function _assertContractDoNotHaveTokens(address _contract) internal view {
        assertEq(token0.balanceOf(_contract), 0);
        assertEq(token1.balanceOf(_contract), 0);

        ISiloConfig.ConfigData memory silo0Config = siloConfig.getConfig(address(silo0));
        ISiloConfig.ConfigData memory silo1Config = siloConfig.getConfig(address(silo1));

        assertEq(IShareToken(silo0Config.collateralShareToken).balanceOf(_contract), 0);
        assertEq(IShareToken(silo0Config.protectedShareToken).balanceOf(_contract), 0);
        assertEq(IShareToken(silo0Config.debtShareToken).balanceOf(_contract), 0);

        assertEq(IShareToken(silo1Config.collateralShareToken).balanceOf(_contract), 0);
        assertEq(IShareToken(silo1Config.protectedShareToken).balanceOf(_contract), 0);
        assertEq(IShareToken(silo1Config.debtShareToken).balanceOf(_contract), 0);
    }

    function _assertReceiverHasSTokens() internal view {
        (address protectedShareToken, address collateralShareToken,) = siloConfig.getShareTokens(address(silo0));

        uint256 pBalance = IERC20(protectedShareToken).balanceOf(LIQUIDATION_HELPER.TOKENS_RECEIVER());
        uint256 cBalance = IERC20(collateralShareToken).balanceOf(LIQUIDATION_HELPER.TOKENS_RECEIVER());

        assertGt(pBalance + cBalance, 0, "expect TOKENS_RECEIVER has sTokens");
    }
}
