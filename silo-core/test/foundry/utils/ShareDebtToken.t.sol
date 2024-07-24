// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {IERC20Errors} from "openzeppelin5/interfaces/draft-IERC6093.sol";

import {ShareDebtToken} from "silo-core/contracts/utils/ShareDebtToken.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";

import {SiloLittleHelper} from  "../_common/SiloLittleHelper.sol";

/*
FOUNDRY_PROFILE=core-test forge test --ffi -vv --mc ShareDebtTokenTest
*/
contract ShareDebtTokenTest is Test, SiloLittleHelper {
    ISiloConfig public siloConfig;
    ShareDebtToken public shareDebtToken;

    function setUp() public {
        siloConfig = _setUpLocalFixture();
        (,, address debtSToken) = siloConfig.getShareTokens(address(silo1));
        shareDebtToken = ShareDebtToken(debtSToken);
    }

    /*
    FOUNDRY_PROFILE=core-test forge test --ffi -vvv --mt test_debtToken_transfer_address_zero
    */
    function test_debtToken_transfer_address_zero() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        shareDebtToken.transfer(address(0), 0);
    }

    /*
    FOUNDRY_PROFILE=core-test forge test --ffi -vvv --mt test_debtToken_transfer_address_zero
    */
    function test_debtToken_transfer_address_zero_withAmount() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        shareDebtToken.transfer(address(0), 1);
    }

    /*
    FOUNDRY_PROFILE=core-test forge test --ffi -vvv --mt test_debtToken_transfer_amountZero
    */
    function test_debtToken_transfer_amountZero() public {
        address receiver = makeAddr("receiver");
        (address collateralSenderBefore, address collateralReceiverBefore) = _getCollateralState();

        shareDebtToken.transfer(receiver, 0);

        _assertCollateralSiloDidNotChanged(collateralSenderBefore, collateralReceiverBefore);
        _assertReceiverIsNotBlockedByAnything();
    }

    /*
    FOUNDRY_PROFILE=core-test forge test --ffi -vvv --mt test_debtToken_transfer_noAllowance
    */
    function test_debtToken_transfer_noAllowance() public {
        address receiver = makeAddr("receiver");

        _depositCollateral(2, address(this), false);
        _depositForBorrow(2, makeAddr("depositor"));
        _borrow(1, address(this));

        vm.expectRevert(IShareToken.AmountExceedsAllowance.selector);
        shareDebtToken.transfer(receiver, 1);
    }

    /*
    FOUNDRY_PROFILE=core-test forge test --ffi -vvv --mt test_debtToken_transfer_withLowAllowance
    */
    function test_debtToken_transfer_withLowAllowance() public {
        address receiver = makeAddr("receiver");

        _depositCollateral(20, address(this), false);
        _depositForBorrow(2, makeAddr("depositor"));
        _borrow(2, address(this));

        vm.prank(receiver);
        shareDebtToken.setReceiveApproval(address(this), 1);

        vm.expectRevert(IShareToken.AmountExceedsAllowance.selector);
        shareDebtToken.transfer(receiver, 2);
    }

    /*
    FOUNDRY_PROFILE=core-test forge test --ffi -vvv --mt test_debtToken_transfer_withAllowance_noCollateral
    */
    function test_debtToken_transfer_withAllowance_noCollateral() public {
        address receiver = makeAddr("receiver");

        _depositCollateral(20, address(this), false);
        _depositForBorrow(2, makeAddr("depositor"));
        _borrow(2, address(this));

        vm.prank(receiver);
        shareDebtToken.setReceiveApproval(address(this), 1);

        vm.expectRevert(IShareToken.RecipientNotSolventAfterTransfer.selector);
        shareDebtToken.transfer(receiver, 1);
    }

    /*
    FOUNDRY_PROFILE=core-test forge test --ffi -vvv --mt test_debtToken_transfer_withAllowance_notSolvent
    */
    function test_debtToken_transfer_withAllowance_notSolvent() public {
        address receiver = makeAddr("receiver");

        _depositCollateral(20, address(this), false);
        _depositCollateral(1, receiver, false);
        _depositForBorrow(2, makeAddr("depositor"));
        _borrow(2, address(this));

        vm.prank(receiver);
        shareDebtToken.setReceiveApproval(address(this), 1);

        vm.expectRevert(IShareToken.RecipientNotSolventAfterTransfer.selector);
        shareDebtToken.transfer(receiver, 1);
    }

    /*
    FOUNDRY_PROFILE=core-test forge test --ffi -vvv --mt test_debtToken_transfer_withAllowance_differentCollateral
    */
    function test_debtToken_transfer_withAllowance_differentCollateral() public {
        address receiver = makeAddr("receiver");

        _depositCollateral(20, address(this), false);
        _depositCollateral(20, receiver, true);
        _borrow(2, address(this));

        vm.prank(receiver);
        shareDebtToken.setReceiveApproval(address(this), 1);

        vm.expectRevert(IShareToken.RecipientNotSolventAfterTransfer.selector);
        shareDebtToken.transfer(receiver, 1);
    }

    /*
    FOUNDRY_PROFILE=core-test forge test --ffi -vvv --mt test_debtToken_transfer_withAllowance_sameCollateral
    */
    function test_debtToken_transfer_withAllowance_sameCollateral() public {
        address receiver = makeAddr("receiver");

        _depositCollateral(20, address(this), false);
        _depositCollateral(20, receiver, false);
        _depositForBorrow(20, makeAddr("depositor"));
        _borrow(2, address(this));

        vm.prank(receiver);
        shareDebtToken.setReceiveApproval(address(this), 1);

        (address collateralSenderBefore, ) = _getCollateralState();

        shareDebtToken.transfer(receiver, 1);

        _assertCollateralSiloWasCopiedFromSenderToReceiver(collateralSenderBefore);
        _assertReceiverIsNotBlockedByAnything();
    }

    function _getCollateralState() private returns (address collateralSender, address collateralReceiver) {
        collateralSender = siloConfig.borrowerCollateralSilo(address(this));
        collateralReceiver = siloConfig.borrowerCollateralSilo(makeAddr("receiver"));
    }

    function _assertCollateralSiloDidNotChanged(
        address _collateralSenderBefore, address _collateralReceiverBefore
    ) private {
        address collateralSenderAfter = siloConfig.borrowerCollateralSilo(address(this));
        address collateralReceiverAfter = siloConfig.borrowerCollateralSilo(makeAddr("receiver"));

        // TODO send all debt, and expect what?
        assertEq(_collateralSenderBefore, collateralSenderAfter, "[a] does not change the sender state");
        assertEq(_collateralReceiverBefore, collateralReceiverAfter, "[a] does not change the receiver state");
    }

    function _assertCollateralSiloWasCopiedFromSenderToReceiver(address _collateralSenderBefore) private {
        address collateralSenderAfter = siloConfig.borrowerCollateralSilo(address(this));
        address collateralReceiverAfter = siloConfig.borrowerCollateralSilo(makeAddr("receiver"));

        // TODO send all debt, and expect what?
        assertEq(_collateralSenderBefore, collateralSenderAfter, "[b] does not change the sender state");
        assertEq(_collateralSenderBefore, collateralReceiverAfter, "[b] does not change the receiver state");
    }


    function _assertReceiverIsNotBlockedByAnything() private {
        address receiver = makeAddr("receiver");

        _depositCollateral(100, receiver, false);
        _depositCollateral(100, receiver, true);
        _depositForBorrow(100, makeAddr("depositor"));
        _borrow(2, receiver);

        vm.prank(receiver);
        silo1.switchCollateralTo();

        _repay(2, receiver);

        vm.prank(receiver);
        silo0.withdraw(2, receiver, receiver);

        vm.prank(receiver);
        silo1.withdraw(2, receiver, receiver);
    }
}
