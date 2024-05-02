// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";

import {SiloFixture} from "../../_common/fixtures/SiloFixture.sol";
import {MintableToken} from "../../_common/MintableToken.sol";
import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";
import {LeverageBorrower, ILeverageBorrower} from "../../_common/LeverageBorrower.sol";

/*
    forge test -vv --ffi --mc LeverageNotPossibleTest
*/
contract LeverageNotPossibleTest is SiloLittleHelper, Test {
    address borrower;
    bool sameAsset;

    function setUp() public {
        borrower = makeAddr("borrower");

        _setUpLocalFixture(SiloConfigsNames.LOCAL_NOT_BORROWABLE);

        (
            ISiloConfig.ConfigData memory cfg0, ISiloConfig.ConfigData memory cfg1,
        ) = silo0.config().getConfigs(address(silo0), borrower, 0 /* always 0 for external calls */);

        assertEq(cfg0.maxLtv, 0, "borrow OFF");
        assertGt(cfg1.maxLtv, 0, "borrow ON");
    }

    /*
    forge test -vv --ffi --mt test_leverage_possible_for_token0
    */
    function test_leverage_possible_for_token0() public {
        uint256 depositAssets = 10e18;
        uint256 borrowAssets = 1e18;
        ILeverageBorrower leverageBorrower = ILeverageBorrower(new LeverageBorrower());
        address depositor = makeAddr("depositor");

        _deposit(depositAssets, depositor, ISilo.CollateralType.Collateral);

        token1.mint(address(leverageBorrower), depositAssets);
        bytes memory data = abi.encode(address(silo1), address(token1), depositAssets);
        
        vm.prank(borrower);
        silo0.leverage(borrowAssets, leverageBorrower, borrower, sameAsset, data);
    }

    /*
    forge test -vv --ffi --mt test_leverage_not_possible_for_token1
    */
    function test_leverage_not_possible_for_token1() public {
        uint256 depositAssets = 10e18;
        uint256 borrowAssets = 1e18;
        ILeverageBorrower leverageBorrower = ILeverageBorrower(new LeverageBorrower());
        address depositor = makeAddr("depositor");

        _depositForBorrow(depositAssets, depositor);

        token0.mint(address(leverageBorrower), depositAssets);
        bytes memory data = abi.encode(address(silo0), address(token0), depositAssets);
        

        vm.prank(borrower);
        vm.expectRevert(ISilo.AboveMaxLtv.selector);
        silo1.leverage(borrowAssets, leverageBorrower, borrower, sameAsset, data);
    }
}
