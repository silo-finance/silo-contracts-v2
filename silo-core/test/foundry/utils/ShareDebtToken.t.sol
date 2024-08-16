// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {IERC20Errors} from "openzeppelin5/interfaces/draft-IERC6093.sol";

import {ShareDebtToken} from "silo-core/contracts/utils/ShareDebtToken.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ERC20Lib} from "silo-core/contracts/utils/siloERC20/lib/ERC20Lib.sol";

import {SiloLittleHelper} from  "../_common/SiloLittleHelper.sol";

/*
FOUNDRY_PROFILE=core-test forge test --ffi -vv --mc ShareDebtTokenTest
*/
contract ShareDebtTokenTest is Test, SiloLittleHelper {
    ISiloConfig public siloConfig;
    ShareDebtToken public shareDebtToken;
    address immutable receiver;

    constructor() {
        receiver = makeAddr("receiver");
    }

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
        shareDebtToken.transfer(address(0), 1);
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
    function test_debtToken_transfer_amountZero_noDebt() public {
        (address collateralSenderBefore, address collateralReceiverBefore) = _getCollateralState();
        assertEq(collateralSenderBefore, address(0), "sender has no state");
        assertEq(collateralReceiverBefore, address(0), "receiver has no state");

        vm.expectRevert(ERC20Lib.ZeroTransfer.selector);
        shareDebtToken.transfer(receiver, 0);
    }

    /*
    FOUNDRY_PROFILE=core-test forge test --ffi -vvv --mt test_debtToken_transfer_amountZero
    */
    function test_transfer_amountZero_withSenderDebt_1token() public {
        _transfer_amountZero_withSenderDebt(SAME_ASSET);
    }

    function test_transfer_amountZero_withSenderDebt_2tokens() public {
        _transfer_amountZero_withSenderDebt(SAME_ASSET);
    }

    function _transfer_amountZero_withSenderDebt(bool _sameAsset) private {
        _depositCollateral(20, address(this), _sameAsset);
        _depositForBorrow(2, makeAddr("depositor"));
        _borrow(2, address(this), _sameAsset);

        vm.expectRevert(ERC20Lib.ZeroTransfer.selector);
        shareDebtToken.transfer(receiver, 0);
    }

    function test_transfer_amountZero_withReceiverDebt_1token() public {
        _transfer_amountZero_withReceiverDebt(SAME_ASSET);
    }

    function test_transfer_amountZero_withReceiverDebt_2tokens() public {
        _transfer_amountZero_withReceiverDebt(TWO_ASSETS);
    }

    function _transfer_amountZero_withReceiverDebt(bool _sameAsset) private {
        _depositCollateral(20, receiver, _sameAsset);
        _depositForBorrow(2, makeAddr("depositor"));
        _borrow(2, receiver, _sameAsset);

        vm.expectRevert(ERC20Lib.ZeroTransfer.selector);
        shareDebtToken.transfer(receiver, 0);
    }

    function test_transfer_amountZero_withSenderReceiverDebt() public {
        _transfer_amountZero_withSenderReceiverDebt(SAME_ASSET, SAME_ASSET);
        _transfer_amountZero_withSenderReceiverDebt(SAME_ASSET, TWO_ASSETS);
        _transfer_amountZero_withSenderReceiverDebt(TWO_ASSETS, SAME_ASSET);
        _transfer_amountZero_withSenderReceiverDebt(TWO_ASSETS, TWO_ASSETS);
    }

    function _transfer_amountZero_withSenderReceiverDebt(bool _senderSameAsset, bool _receiverSameAsset) private {
        _depositCollateral(20, address(this), _senderSameAsset);
        _depositCollateral(20, receiver, _receiverSameAsset);
        _depositForBorrow(20, makeAddr("depositor"));
        _borrow(2, address(this), _senderSameAsset);
        _borrow(2, receiver, _receiverSameAsset);

        vm.expectRevert(ERC20Lib.ZeroTransfer.selector);
        shareDebtToken.transfer(receiver, 0);
    }

    /*
    FOUNDRY_PROFILE=core-test forge test --ffi -vvv --mt test_debtToken_transfer_noAllowance
    */
    function test_debtToken_transfer_noAllowance() public {
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
        _depositCollateral(20, address(this), TWO_ASSETS);
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
    function test_debtToken_transfer_withAllowance_noCollateral_1token() public {
        _transfer_withAllowance_noCollateral(SAME_ASSET);
    }

    function test_debtToken_transfer_withAllowance_noCollateral_2tokens() public {
        _transfer_withAllowance_noCollateral(TWO_ASSETS);
    }

    function _transfer_withAllowance_noCollateral(bool _sameAsset) private {
        _depositCollateral(20, address(this), _sameAsset);
        _depositForBorrow(2, makeAddr("depositor"));
        _borrow(2, address(this), _sameAsset);

        vm.prank(receiver);
        shareDebtToken.setReceiveApproval(address(this), 1);

        vm.expectRevert(IShareToken.RecipientNotSolventAfterTransfer.selector);
        shareDebtToken.transfer(receiver, 1);
    }

    /*
    FOUNDRY_PROFILE=core-test forge test --ffi -vvv --mt test_debtToken_transfer_withAllowance_notSolvent
    */
    function test_debtToken_transfer_withAllowance_notSolvent_1token() public {
        _transfer_withAllowance_notSolvent(SAME_ASSET);
    }

    function test_debtToken_transfer_withAllowance_notSolvent_2tokens() public {
        _transfer_withAllowance_notSolvent(TWO_ASSETS);
    }

    function _transfer_withAllowance_notSolvent(bool _sameAsset) public {
        _depositCollateral(20, address(this), _sameAsset);
        _depositCollateral(1, receiver, _sameAsset);
        _depositForBorrow(2, makeAddr("depositor"));
        _borrow(2, address(this), _sameAsset);

        vm.prank(receiver);
        shareDebtToken.setReceiveApproval(address(this), 1);

        vm.expectRevert(IShareToken.RecipientNotSolventAfterTransfer.selector);
        shareDebtToken.transfer(receiver, 1);
    }

    /*
    FOUNDRY_PROFILE=core-test forge test --ffi -vvv --mt test_debtToken_transfer_withAllowance_differentCollateral
    */
    function test_debtToken_transfer_withAllowance_differentCollateral_1token() public {
        _transfer_withAllowance_differentCollateral(SAME_ASSET);
    }

    function test_debtToken_transfer_withAllowance_differentCollateral_2tokens() public {
        _transfer_withAllowance_differentCollateral(TWO_ASSETS);
    }

    function _transfer_withAllowance_differentCollateral(bool _sameAsset) private {
        _depositCollateral(20, address(this), _sameAsset);
        _depositCollateral(20, receiver, !_sameAsset);
        _depositForBorrow(10, makeAddr("depositor"));
        _borrow(2, address(this), _sameAsset);

        vm.prank(receiver);
        shareDebtToken.setReceiveApproval(address(this), 1);

        vm.expectRevert(IShareToken.RecipientNotSolventAfterTransfer.selector);
        shareDebtToken.transfer(receiver, 1);
    }

    /*
    FOUNDRY_PROFILE=core-test forge test --ffi -vvv --mt test_debtToken_transfer_withAllowance_sameCollateral
    */
    function test_debtToken_transfer_withAllowance_sameCollateral_1token() public {
        _transfer_withAllowance_sameCollateral(SAME_ASSET);
    }

    function test_debtToken_transfer_withAllowance_sameCollateral_2tokens() public {
        _transfer_withAllowance_sameCollateral(TWO_ASSETS);
    }

    function _transfer_withAllowance_sameCollateral(bool _sameAsset) private {
        _depositCollateral(20, address(this), _sameAsset);
        _depositCollateral(20, receiver, _sameAsset);
        _depositForBorrow(20, makeAddr("depositor"));
        _borrow(2, address(this), _sameAsset);

        vm.prank(receiver);
        shareDebtToken.setReceiveApproval(address(this), 1);

        (address collateralSenderBefore, ) = _getCollateralState();

        shareDebtToken.transfer(receiver, 1);

        _assertCollateralSiloWasCopiedFromSenderToReceiver(collateralSenderBefore);
        _assertReceiverIsNotBlockedByAnything();
    }

    /*
    FOUNDRY_PROFILE=core-test forge test --ffi -vvv --mt test_debtToken_transfer_withAllowance_withSameDebt_1token
    */
    function test_debtToken_transfer_withAllowance_withSameDebt_1token() public {
        _transfer_withAllowance_withSameDebt(SAME_ASSET);
    }

    function test_debtToken_transfer_withAllowance_withSameDebt_2tokens() public {
        _transfer_withAllowance_withSameDebt(TWO_ASSETS);
    }

    function _transfer_withAllowance_withSameDebt(bool _sameAsset) private {
        _depositCollateral(20, address(this), _sameAsset);
        _depositCollateral(20, receiver, _sameAsset);
        _depositForBorrow(20, makeAddr("depositor"));

        _borrow(2, address(this), _sameAsset);
        _borrow(1, receiver, _sameAsset);

        vm.prank(receiver);
        shareDebtToken.setReceiveApproval(address(this), 1);

        (address collateralSenderBefore, ) = _getCollateralState();

        shareDebtToken.transfer(receiver, 1);

        _assertCollateralSiloWasCopiedFromSenderToReceiver(collateralSenderBefore);
        _assertReceiverIsNotBlockedByAnything();
    }

    /*
    FOUNDRY_PROFILE=core-test forge test --ffi -vvv --mt test_debtToken_transfer_withAllowance_withDifferentDebt_
    */
    function test_debtToken_transfer_withAllowance_withDifferentDebt_1token() public {
        _transfer_withAllowance_withDifferentDebt(SAME_ASSET);
    }

    function test_debtToken_transfer_withAllowance_withDifferentDebt_2tokens() public {
        _transfer_withAllowance_withDifferentDebt(TWO_ASSETS);
    }

    function _transfer_withAllowance_withDifferentDebt(bool _sameAsset) private {
        _depositCollateral(20, address(this), _sameAsset);
        _depositCollateral(20, receiver, !_sameAsset);
        _depositForBorrow(20, makeAddr("depositor"));

        _borrow(2, address(this), _sameAsset);
        _borrow(1, receiver, !_sameAsset);

        vm.prank(receiver);
        shareDebtToken.setReceiveApproval(address(this), 1);

        shareDebtToken.transfer(receiver, 1);
    }

    /*
    FOUNDRY_PROFILE=core-test forge test --ffi -vvv --mt test_debtToken_transferAll
    */
    function test_debtToken_transferAll_1token() public {
        _transferAll(SAME_ASSET);
    }

    function test_debtToken_transferAll_2tokens() public {
        _transferAll(TWO_ASSETS);
    }

    function _transferAll(bool _sameAsset) public {
        uint256 toBorrow = 2;

        _depositCollateral(20, address(this), _sameAsset);
        _depositCollateral(20, receiver, _sameAsset);
        _depositForBorrow(2, makeAddr("depositor"));
        _printStats(siloConfig, address(this));
        _borrow(toBorrow, address(this), _sameAsset);

        vm.prank(receiver);
        shareDebtToken.setReceiveApproval(address(this), toBorrow);

        (address collateralSenderBefore, address collateralReceiverBefore) = _getCollateralState();
        assertEq(collateralReceiverBefore, address(0), "[transferAll] receiver collateral is empty");

        shareDebtToken.transfer(receiver, toBorrow);

        (address collateralSenderAfter, address collateralReceiverAfter) = _getCollateralState();

        assertEq(collateralSenderBefore, collateralSenderAfter, "[transferAll] sender history is not cleared");
        assertEq(collateralReceiverAfter, collateralSenderBefore, "[transferAll] state copied sender -> receiver");

        _assertReceiverIsNotBlockedByAnything();
    }

    /*
    FOUNDRY_PROFILE=core-test forge test --ffi -vvv --mt test_debtToken_transfer_debtExistInOtherSilo_
    */
    function test_debtToken_transfer_debtExistInOtherSilo_1token() public {
        _transferAll(SAME_ASSET);
    }

    function test_debtToken_transfer_debtExistInOtherSilo_2tokens() public {
        _transferAll(TWO_ASSETS);
    }

    function _transfer_debtExistInOtherSilo(bool _sameAsset) public {
        uint256 toBorrow = 2;

        _depositCollateral(20, address(this), _sameAsset);
        _depositCollateral(20, receiver, !_sameAsset);
        _depositForBorrow(2, makeAddr("depositor"));
        _printStats(siloConfig, address(this));

        _borrow(toBorrow, address(this), _sameAsset);

        vm.prank(receiver);
        _sameAsset ? silo0.borrow(1, receiver, receiver) : silo0.borrowSameAsset(1, receiver, receiver);

        vm.prank(receiver);
        shareDebtToken.setReceiveApproval(address(this), toBorrow);

        vm.expectRevert(ISiloConfig.DebtExistInOtherSilo.selector);
        shareDebtToken.transfer(receiver, toBorrow);
    }

    function _getCollateralState() private returns (address collateralSender, address collateralReceiver) {
        collateralSender = siloConfig.borrowerCollateralSilo(address(this));
        collateralReceiver = siloConfig.borrowerCollateralSilo(makeAddr("receiver"));
    }

    function _assertCollateralSiloDidNotChanged(
        address _collateralSenderBefore, address _collateralReceiverBefore
    ) private {
        (address collateralSenderAfter, address collateralReceiverAfter) = _getCollateralState();

        assertEq(_collateralSenderBefore, collateralSenderAfter, "[a] does not change the sender state");
        assertEq(_collateralReceiverBefore, collateralReceiverAfter, "[a] does not change the receiver state");
    }

    function _assertCollateralSiloWasCopiedFromSenderToReceiver(address _collateralSenderBefore) private {
        address collateralSenderAfter = siloConfig.borrowerCollateralSilo(address(this));
        address collateralReceiverAfter = siloConfig.borrowerCollateralSilo(makeAddr("receiver"));

        assertEq(_collateralSenderBefore, collateralSenderAfter, "[b] does not change the sender state");
        assertEq(_collateralSenderBefore, collateralReceiverAfter, "[b] copies state of sender to receiver");
    }

    function _assertReceiverIsNotBlockedByAnything() private {
        _depositCollateral(100, receiver, SAME_ASSET);
        _depositCollateral(100, receiver, TWO_ASSETS);
        _depositForBorrow(100, makeAddr("depositor"));
        _borrow(2, receiver);

        vm.prank(receiver);
        silo1.switchCollateralToThisSilo();

        _repay(2, receiver);

        vm.prank(receiver);
        silo0.withdraw(2, receiver, receiver);

        vm.prank(receiver);
        silo1.withdraw(2, receiver, receiver);
    }
}
