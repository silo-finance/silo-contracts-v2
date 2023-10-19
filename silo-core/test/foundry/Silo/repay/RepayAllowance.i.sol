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
    forge test --ffi -vv--mc RepayAllowanceTest
*/
contract RepayAllowanceTest is SiloLittleHelper, Test {
    uint256 internal constant ASSETS = 1e18;

    address immutable DEPOSITOR;
    address immutable RECEIVER;
    address immutable BORROWER;

    ISiloConfig siloConfig;

    constructor() {
        DEPOSITOR = makeAddr("Depositor");
        RECEIVER = makeAddr("Other");
        BORROWER = makeAddr("Borrower");
    }

    function setUp() public {
        siloConfig = _setUpLocalFixture();

        _deposit(ASSETS * 10, BORROWER);
        _depositForBorrow(ASSETS, DEPOSITOR);
        _borrow(ASSETS, BORROWER);
    }

    /*
    forge test --ffi -vv --mt test_repay_WithoutAllowance
    */
    function test_repay_WithoutAllowance() public {
        (,, address debtShareToken) = siloConfig.getShareTokens(address(silo1));

        assertEq(IShareToken(debtShareToken).balanceOf(BORROWER), ASSETS, "BORROWER debt before");

        uint256 toRepay = ASSETS / 2;

        token1.mint(address(this), toRepay);
        token1.approve(address(silo1), toRepay);
        silo1.repay(toRepay, BORROWER);

        assertEq(IShareToken(debtShareToken).balanceOf(BORROWER), ASSETS - toRepay, "BORROWER debt after reduced");
    }
}
