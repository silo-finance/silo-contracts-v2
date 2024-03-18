// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IERC20R} from "silo-core/contracts/interfaces/IERC20R.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloERC4626Lib} from "silo-core/contracts/lib/SiloERC4626Lib.sol";

import {MintableToken} from "../_common/MintableToken.sol";
import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc IsSolventTest
*/
contract IsSolventTest is SiloLittleHelper, Test {
    ISiloConfig siloConfig;

    function setUp() public {
        siloConfig = _setUpLocalFixture();
    }

    /*
    forge test -vv --ffi --mt test_isSolvent_onDebtTransfer
    this test covers the bug when wrong configs are fetched after debt transfer
    */
    function test_isSolvent_onDebtTransfer() public {
        uint256 assets = 1e18;
        address depositor = makeAddr("Depositor");
        address borrower = makeAddr("Borrower");
        address recipient = makeAddr("Recipient");

        _deposit(assets, borrower);
        _depositForBorrow(assets, depositor);

        _deposit(2, recipient);

        _borrow(assets / 2, borrower);

        (,, address debtShareToken) = silo1.config().getShareTokens(address(silo1));

        vm.prank(recipient);
        IERC20R(debtShareToken).setReceiveApproval(borrower, 1);

        // isSolvent fetching getConfings() for "this" silo and first confing is collateral onc,
        // so on after transferring debt, when we call silo.isSolvent, we want to call OTHER/collateral silo
        vm.expectCall(address(silo0), abi.encodeWithSelector(ISilo.isSolvent.selector, recipient));

        vm.prank(borrower);
        IShareToken(debtShareToken).transfer(recipient, 1);
    }

    /*
    forge test -vv --ffi --mt test_isSolvent_onDebtTransfer
    */
    function test_isSolvent_RecipientNotSolventAfterTransfer() public {
        uint256 assets = 1e18;
        address depositor = makeAddr("Depositor");
        address borrower = makeAddr("Borrower");
        address recipient = makeAddr("Recipient");

        _deposit(assets, borrower);
        _depositForBorrow(assets, depositor);

        _borrow(assets / 2, borrower);

        (,, address debtShareToken) = silo1.config().getShareTokens(address(silo1));

        vm.prank(recipient);
        IERC20R(debtShareToken).setReceiveApproval(borrower, 1);

        vm.prank(borrower);
        vm.expectRevert(IShareToken.RecipientNotSolventAfterTransfer.selector);
        IShareToken(debtShareToken).transfer(recipient, 1);
    }
}
