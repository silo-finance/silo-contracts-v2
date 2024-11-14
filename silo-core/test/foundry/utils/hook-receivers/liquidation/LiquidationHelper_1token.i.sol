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
import {LiquidationCall1TokenTest} from "./LiquidationCall_1token.i.sol";

/*
    FOUNDRY_PROFILE=core-test forge test -vv --ffi --mc LiquidationHelper1TokenTest
*/
contract LiquidationHelper1TokenTest is LiquidationCall1TokenTest {
    address payable public constant TOKENS_RECEIVER = payable(address(123));

    DexSwapMock immutable DEXSWAP;
    LiquidationHelper immutable LIQUIDATION_HELPER;

    ILiquidationHelper.LiquidationData liquidationData;
    LiquidationHelper.DexSwapInput[] dexSwapInput;

    constructor() {
        DEXSWAP = new DexSwapMock();
        LIQUIDATION_HELPER = new LiquidationHelper(makeAddr("nativeToken"), address(DEXSWAP), TOKENS_RECEIVER);
    }

    function setUp() public override {
        super.setUp();

        liquidationData.user = BORROWER;
        liquidationData.hook = partialLiquidation;
        liquidationData.collateralAsset = address(token0);
    }

    /*
    forge test -vv --ffi --mt test_liquidationCall_UnexpectedDebtToken
    */
    function test_liquidationCall_UnexpectedDebtToken_1token() public override {
        uint256 maxDebtToCover = 1;
        bool receiveSToken;

        vm.expectRevert(ISilo.Unsupported.selector);
        _executeLiquidation(address(token0), address(token1), BORROWER, maxDebtToCover, receiveSToken);

        _afterEach();
    }

    function _executeLiquidation(
        address _collateralAsset,
        address _debtAsset,
        address /* _user */,
        uint256 _maxDebtToCover,
        bool _receiveSToken
    ) internal override returns (uint256 withdrawCollateral, uint256 repayDebtAssets) {
        return LIQUIDATION_HELPER.executeLiquidation(silo0, _debtAsset, _maxDebtToCover, liquidationData, dexSwapInput);
    }

    function _afterEach() internal view override {
        super._afterEach();

        _assertContractDoNotHaveTokens(address(LIQUIDATION_HELPER));
    }
}
