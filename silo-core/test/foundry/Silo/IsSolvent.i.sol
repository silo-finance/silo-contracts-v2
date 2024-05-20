// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

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
    function test_isSolvent_onDebtTransfer_1token() public {
        _isSolvent_onDebtTransfer(SAME_ASSET);
    }

    function test_isSolvent_onDebtTransfer_2tokens() public {
        _isSolvent_onDebtTransfer(TWO_ASSETS);
    }

    function _isSolvent_onDebtTransfer(bool _sameAsset) private {
        uint256 assets = 1e18;
        address depositor = makeAddr("Depositor");
        address borrower = makeAddr("Borrower");
        address recipient = makeAddr("Recipient");

        _depositCollateral(assets, borrower, _sameAsset);
        _depositForBorrow(assets, depositor);

        _depositCollateral(2, recipient, _sameAsset);

        _borrow(assets / 2, borrower, _sameAsset);

        ISilo collateralSilo = _sameAsset ? silo1 : silo0;

        (, address collateralShareToken,) = collateralSilo.config().getShareTokens(address(collateralSilo));
        (,, address debtShareToken) = silo1.config().getShareTokens(address(silo1));

        vm.prank(recipient);
        IERC20R(debtShareToken).setReceiveApproval(borrower, 1);

        // it does not matter which silo we will call for checking borrower solvency
        vm.expectCall(address(silo1), abi.encodeWithSelector(ISilo.isSolvent.selector, recipient));
        vm.expectCall(debtShareToken, abi.encodeWithSelector(IERC20.balanceOf.selector, recipient));
        vm.expectCall(collateralShareToken, abi.encodeWithSelector(IERC20.balanceOf.selector, recipient));

        vm.prank(borrower);
        IShareToken(debtShareToken).transfer(recipient, 1);
    }

    /*
    forge test -vv --ffi --mt test_isSolvent_RecipientNotSolventAfterTransfer
    */
    function test_isSolvent_RecipientNotSolventAfterTransfer_1token() public {
        _isSolvent_RecipientNotSolventAfterTransfer(SAME_ASSET);
    }

    function test_isSolvent_RecipientNotSolventAfterTransfer_2tokens() public {
        _isSolvent_RecipientNotSolventAfterTransfer(TWO_ASSETS);
    }

    function _isSolvent_RecipientNotSolventAfterTransfer(bool _sameAsset) private {
        uint256 assets = 1e18;
        address depositor = makeAddr("Depositor");
        address borrower = makeAddr("Borrower");
        address recipient = makeAddr("Recipient");

        _depositCollateral(assets, borrower, _sameAsset);
        _depositForBorrow(assets, depositor);

        _borrow(assets / 2, borrower, _sameAsset);

        (,, address debtShareToken) = silo1.config().getShareTokens(address(silo1));

        vm.prank(recipient);
        IERC20R(debtShareToken).setReceiveApproval(borrower, 1);

        vm.prank(borrower);
        vm.expectRevert(IShareToken.RecipientNotSolventAfterTransfer.selector);
        IShareToken(debtShareToken).transfer(recipient, 1);
    }
}
