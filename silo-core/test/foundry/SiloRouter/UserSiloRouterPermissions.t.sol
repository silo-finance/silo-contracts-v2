// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {SiloRouterV2Deploy} from "silo-core/deploy/SiloRouterV2Deploy.s.sol";
import {SiloRouterV2} from "silo-core/contracts/silo-router/SiloRouterV2.sol";
import {SiloRouterV2Implementation} from "silo-core/contracts/silo-router/SiloRouterV2Implementation.sol";
import {ISiloRouterV2Implementation} from "silo-core/contracts/interfaces/ISiloRouterV2Implementation.sol";
import {IWrappedNativeToken} from "silo-core/contracts/interfaces/IWrappedNativeToken.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IPendleWrapperLike} from "silo-core/contracts/interfaces/IPendleWrapperLike.sol";

// FOUNDRY_PROFILE=core_test forge test -vv --ffi --mc UserSiloRouterPermissionsTest
contract UserSiloRouterPermissionsTest is Test {
    SiloRouterV2 public router;
    SiloRouterV2Implementation public userSiloRouter;

    IWrappedNativeToken public mockNative = IWrappedNativeToken(makeAddr("MockNative"));
    IERC20 public mockToken = IERC20(makeAddr("MockToken"));
    IPendleWrapperLike public mockWrapper = IPendleWrapperLike(makeAddr("MockWrapper"));
    address public receiver = makeAddr("Receiver");
    address public spender = makeAddr("Spender");
    ISilo public mockSilo = ISilo(makeAddr("MockSilo"));

    function setUp() public {
        SiloRouterV2Deploy deploy = new SiloRouterV2Deploy();
        deploy.disableDeploymentsSync();

        router = deploy.run();

        userSiloRouter = SiloRouterV2Implementation(payable(router.IMPLEMENTATION()));
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi --mt test_wrap_onlySiloRouter -vv
    function test_wrap_onlySiloRouter() public {
        vm.expectRevert(ISiloRouterV2Implementation.OnlySiloRouter.selector);
        userSiloRouter.wrap{value:0}(mockNative, 100);
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi --mt test_unwrap_onlySiloRouter -vv
    function test_unwrap_onlySiloRouter() public {
        vm.expectRevert(ISiloRouterV2Implementation.OnlySiloRouter.selector);
        userSiloRouter.unwrap{value:0}(mockNative, 100);
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi --mt test_unwrapAll_onlySiloRouter -vv
    function test_unwrapAll_onlySiloRouter() public {
        vm.expectRevert(ISiloRouterV2Implementation.OnlySiloRouter.selector);
        userSiloRouter.unwrapAll{value:0}(mockNative);
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi --mt test_wrapPendleLP_onlySiloRouter -vv
    function test_wrapPendleLP_onlySiloRouter() public {
        vm.expectRevert(ISiloRouterV2Implementation.OnlySiloRouter.selector);
        userSiloRouter.wrapPendleLP(mockWrapper, mockToken, receiver, 100);
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi --mt test_unwrapPendleLP_onlySiloRouter -vv
    function test_unwrapPendleLP_onlySiloRouter() public {
        vm.expectRevert(ISiloRouterV2Implementation.OnlySiloRouter.selector);
        userSiloRouter.unwrapPendleLP(mockWrapper, receiver, 100);
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi --mt test_unwrapAllPendleLP_onlySiloRouter -vv
    function test_unwrapAllPendleLP_onlySiloRouter() public {
        vm.expectRevert(ISiloRouterV2Implementation.OnlySiloRouter.selector);
        userSiloRouter.unwrapAllPendleLP(mockWrapper, receiver);
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi --mt test_sendValue_onlySiloRouter -vv
    function test_sendValue_onlySiloRouter() public {
        address payable receiverPayable = payable(receiver);
        
        vm.expectRevert(ISiloRouterV2Implementation.OnlySiloRouter.selector);
        userSiloRouter.sendValue(receiverPayable, 100);
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi --mt test_sendValueAll_onlySiloRouter -vv
    function test_sendValueAll_onlySiloRouter() public {
        address payable receiverPayable = payable(receiver);
        
        vm.expectRevert(ISiloRouterV2Implementation.OnlySiloRouter.selector);
        userSiloRouter.sendValueAll(receiverPayable);
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi --mt test_transfer_onlySiloRouter -vv
    function test_transfer_onlySiloRouter() public {
        vm.expectRevert(ISiloRouterV2Implementation.OnlySiloRouter.selector);
        userSiloRouter.transfer(mockToken, receiver, 100);
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi --mt test_transferAll_onlySiloRouter -vv
    function test_transferAll_onlySiloRouter() public {
        vm.expectRevert(ISiloRouterV2Implementation.OnlySiloRouter.selector);
        userSiloRouter.transferAll(mockToken, receiver);
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi --mt test_transferFrom_onlySiloRouter -vv
    function test_transferFrom_onlySiloRouter() public {
        vm.expectRevert(ISiloRouterV2Implementation.OnlySiloRouter.selector);
        userSiloRouter.transferFrom(mockToken, receiver, 100);
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi --mt test_approve_onlySiloRouter -vv
    function test_approve_onlySiloRouter() public {
        vm.expectRevert(ISiloRouterV2Implementation.OnlySiloRouter.selector);
        userSiloRouter.approve(mockToken, spender, 100);
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi --mt test_deposit_onlySiloRouter -vv
    function test_deposit_onlySiloRouter() public {
        
        
        vm.expectRevert(ISiloRouterV2Implementation.OnlySiloRouter.selector);
        userSiloRouter.deposit(mockSilo, 100, ISilo.CollateralType.Collateral);
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi --mt test_withdraw_onlySiloRouter -vv
    function test_withdraw_onlySiloRouter() public {
        vm.expectRevert(ISiloRouterV2Implementation.OnlySiloRouter.selector);
        userSiloRouter.withdraw(mockSilo, 100, receiver, ISilo.CollateralType.Collateral);
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi --mt test_withdrawAll_onlySiloRouter -vv
    function test_withdrawAll_onlySiloRouter() public {
        vm.expectRevert(ISiloRouterV2Implementation.OnlySiloRouter.selector);
        userSiloRouter.withdrawAll(mockSilo, receiver, ISilo.CollateralType.Collateral);
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi --mt test_borrow_onlySiloRouter -vv
    function test_borrow_onlySiloRouter() public {
        vm.expectRevert(ISiloRouterV2Implementation.OnlySiloRouter.selector);
        userSiloRouter.borrow(mockSilo, 100, receiver);
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi --mt test_borrowSameAsset_onlySiloRouter -vv
    function test_borrowSameAsset_onlySiloRouter() public {
        vm.expectRevert(ISiloRouterV2Implementation.OnlySiloRouter.selector);
        userSiloRouter.borrowSameAsset(mockSilo, 100, receiver);
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi --mt test_repay_onlySiloRouter -vv
    function test_repay_onlySiloRouter() public {
        vm.expectRevert(ISiloRouterV2Implementation.OnlySiloRouter.selector);
        userSiloRouter.repay(mockSilo, 100);
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi --mt test_repayAll_onlySiloRouter -vv
    function test_repayAll_onlySiloRouter() public {
        vm.expectRevert(ISiloRouterV2Implementation.OnlySiloRouter.selector);
        userSiloRouter.repayAll(mockSilo);
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi --mt test_repayAllNative_onlySiloRouter -vv
    function test_repayAllNative_onlySiloRouter() public {
        vm.expectRevert(ISiloRouterV2Implementation.OnlySiloRouter.selector);
        userSiloRouter.repayAllNative(mockNative, mockSilo);
    }
}
