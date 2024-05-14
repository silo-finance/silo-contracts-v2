// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IERC20Errors} from "openzeppelin5/interfaces/draft-IERC6093.sol";

import {TokenMock} from "silo-core/test/foundry/_mocks/TokenMock.sol";
import {SiloFixture} from "../../_common/fixtures/SiloFixture.sol";

import {MintableToken} from "../../_common/MintableToken.sol";
import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";
import {LeverageBorrower, ILeverageBorrower} from "../../_common/LeverageBorrower.sol";

/*
    forge test --ffi -vv --mc LeverageAllowanceTest
*/
contract LeverageAllowanceTest is SiloLittleHelper, Test {
    uint256 internal constant ASSETS = 1e18;

    address immutable DEPOSITOR;
    address immutable RECEIVER;
    address immutable BORROWER;

    ISiloConfig siloConfig;
    bool sameAsset;

    ILeverageBorrower leverageBorrower = ILeverageBorrower(new LeverageBorrower());

    constructor() {
        DEPOSITOR = makeAddr("Depositor");
        RECEIVER = makeAddr("Other");
        BORROWER = makeAddr("Borrower");
    }

    function setUp() public {
        siloConfig = _setUpLocalFixture();

        _deposit(ASSETS, DEPOSITOR);
        _depositForBorrow(ASSETS, DEPOSITOR);
    }

    /*
    forge test --ffi -vv --mt test_leverage_WithoutAllowance
    */
    function test_leverage_WithoutAllowance() public {
        bytes memory data = abi.encode(address(silo1), address(token1), ASSETS);
        
        token1.mint(address(leverageBorrower), ASSETS);

        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(this), 0, ASSETS)
        );
        silo0.leverage(ASSETS, leverageBorrower, BORROWER, sameAsset, data);
    }

    /*
    forge test --ffi -vv --mt test_leverage_WithAllowance
    */
    function test_leverage_WithAllowance() public {
        (,, address debtShareToken) = siloConfig.getShareTokens(address(silo0));

        vm.prank(BORROWER);
        IShareToken(debtShareToken).approve(address(this), ASSETS);

        assertEq(IShareToken(debtShareToken).balanceOf(BORROWER), 0, "BORROWER no debt before");
        assertEq(IShareToken(debtShareToken).balanceOf(DEPOSITOR), 0, "DEPOSITOR no debt before");
        assertEq(IShareToken(debtShareToken).balanceOf(address(leverageBorrower)), 0, "leverageBorrower no debt before");

        assertEq(token1.balanceOf(address(leverageBorrower)), 0, "leverageBorrower no tokens before");

        token1.mint(address(leverageBorrower), ASSETS);
        bytes memory data = abi.encode(address(silo1), address(token1), ASSETS);

        silo0.leverage(ASSETS / 2, leverageBorrower, BORROWER, sameAsset, data);

        assertEq(IShareToken(debtShareToken).balanceOf(BORROWER), ASSETS / 2, "BORROWER has debt after");
        assertEq(IShareToken(debtShareToken).balanceOf(DEPOSITOR), 0, "DEPOSITOR no debt after");
        assertEq(IShareToken(debtShareToken).balanceOf(address(leverageBorrower)), 0, "leverageBorrower no debt before");

        assertEq(token1.balanceOf(address(leverageBorrower)), 0, "leverageBorrower got tokens after");

        assertEq(IShareToken(debtShareToken).allowance(BORROWER, address(this)), ASSETS / 2, "allowance reduced");
    }
}
