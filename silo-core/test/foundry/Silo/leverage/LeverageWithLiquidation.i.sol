// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";


import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";
import {LeverageBorrower, ILeverageBorrower} from "../../_common/LeverageBorrower.sol";

/*
    forge test -vv --ffi --mc LeverageWithLiquidationTest
*/
contract LeverageWithLiquidationTest is SiloLittleHelper, Test, ILeverageBorrower {
    bytes32 public constant LEVERAGE_CALLBACK = keccak256("ILeverageBorrower.onLeverage");

    function setUp() public {
        ISiloConfig siloConfig = _setUpLocalFixture("ETH-USDC_UniswapV3_Silo");
        assertTrue(siloConfig.getConfig(address(silo0)).maxLtv != 0, "we need borrow to be allowed");
    }

    /*
    forge test -vv --ffi --mt test_leverage_liquidation_woDeposit
    */
    function test_leverage_liquidation_woDeposit() public {
        uint256 borrowAssets = 1e18;
        ILeverageBorrower leverageBorrower = this;

        address borrower = makeAddr("borrower");
        address depositor = makeAddr("depositor");

        _depositForBorrow(borrowAssets, depositor);

        bytes memory data;
        vm.prank(borrower);
        // before reentrancy protection, if debt or collateral is 0, then liquidation will fail with NoDebtToCover
        vm.expectRevert("ReentrancyGuard: reentrant call");
        silo1.leverage(borrowAssets, leverageBorrower, borrower, data);
    }

    /*
    forge test -vv --ffi --mt test_leverage_free_flashloan
    */
    function test_leverage_free_flashloan() public {
        uint256 borrowAssets = 1e18;
        ILeverageBorrower leverageBorrower = this;

        address borrower = makeAddr("borrower");
        address depositor = makeAddr("depositor");

        _depositForBorrow(borrowAssets, depositor);
        _deposit(1, borrower);

        bytes memory data;
        vm.prank(borrower);
        // this will revert, because we can not enter liquidation when we do leverage
        // without reentrancy it is possible
        vm.expectRevert("ReentrancyGuard: reentrant call");
        silo1.leverage(borrowAssets, leverageBorrower, borrower, data);
    }

    function onLeverage(
        address /* _initiator */,
        address _borrower,
        address _asset,
        uint256 /* _assets */,
        bytes calldata /* _data */
    )
        external
        returns (bytes32)
    {
        if (silo1.isSolvent(_borrower)) revert("atm user should not be solvent");
        if (token1.balanceOf(address(this)) != 1e18) revert("should have tokens already");

        address collateralAsset = address(token0);
        address debtAsset = _asset;

        token1.approve(msg.sender, 1e18);
        ISilo(msg.sender).liquidationCall(collateralAsset, debtAsset, _borrower, type(uint256).max, false);

        return LEVERAGE_CALLBACK;
    }
}
