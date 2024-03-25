// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

import {TokenMock} from "silo-core/test/foundry/_mocks/TokenMock.sol";
import {SiloFixture} from "../../_common/fixtures/SiloFixture.sol";

import {MintableToken} from "../../_common/MintableToken.sol";
import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";

/*
    forge test --ffi -vv --mc BorrowAllowanceTest
*/
contract BorrowAllowanceTest is SiloLittleHelper, Test {
    uint256 internal constant ASSETS = 1e18;

    address immutable DEPOSITOR;
    address immutable RECEIVER;
    address immutable BORROWER;

    ISiloConfig siloConfig;
    bool sameToken = false;

    constructor() {
        DEPOSITOR = makeAddr("Depositor");
        RECEIVER = makeAddr("Other");
        BORROWER = makeAddr("Borrower");
    }

    function setUp() public {
        siloConfig = _setUpLocalFixture();

        _deposit(ASSETS * 10, BORROWER);
        _depositForBorrow(ASSETS, DEPOSITOR);
    }

    /*
    forge test --ffi -vv --mt test_borrow_WithoutAllowance
    */
    function test_borrow_WithoutAllowance(bool _sameToken) public { // TODO will it do just two runs?
        vm.expectRevert("ERC20: insufficient allowance");
        silo1.borrow(ASSETS, RECEIVER, BORROWER, _sameToken);
    }

    /*
    forge test --ffi -vv --mt test_borrow_WithAllowance
    */
    function test_borrow_WithAllowance() public {
        (,, address debtShareToken) = siloConfig.getShareTokens(address(silo1));

        vm.prank(BORROWER);
        IShareToken(debtShareToken).approve(address(this), ASSETS);

        assertEq(IShareToken(debtShareToken).balanceOf(BORROWER), 0, "BORROWER no debt before");
        assertEq(IShareToken(debtShareToken).balanceOf(DEPOSITOR), 0, "DEPOSITOR no debt before");
        assertEq(IShareToken(debtShareToken).balanceOf(RECEIVER), 0, "RECEIVER no debt before");

        assertEq(token1.balanceOf(RECEIVER), 0, "RECEIVER no tokens before");

        silo1.borrow(ASSETS / 2, RECEIVER, BORROWER, sameToken);

        assertEq(IShareToken(debtShareToken).balanceOf(BORROWER), ASSETS / 2, "BORROWER has debt after");
        assertEq(IShareToken(debtShareToken).balanceOf(DEPOSITOR), 0, "DEPOSITOR no debt after");
        assertEq(IShareToken(debtShareToken).balanceOf(RECEIVER), 0, "RECEIVER no debt after");

        assertEq(token1.balanceOf(RECEIVER), ASSETS / 2, "RECEIVER got tokens after");

        assertEq(IShareToken(debtShareToken).allowance(BORROWER, address(this)), ASSETS / 2, "allowance reduced");
    }
}
