// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "openzeppelin5/access/Ownable.sol";

import {XSiloManagement, INotificationReceiver, Stream} from "../../../contracts/modules/XSiloManagement.sol";

/*
FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mc XSiloManagementTest
*/
contract XSiloManagementTest is Test {
    XSiloManagement mgm;

    event NotificationReceiverUpdate(INotificationReceiver indexed newNotificationReceiver);
    event StreamUpdate(Stream indexed newStream);

    function setUp() public {
        mgm = new XSiloManagement(address(this));
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_setNotificationReceiver
    */
    function test_setNotificationReceiver() public {
        INotificationReceiver newAddr = INotificationReceiver(makeAddr("new receiver"));

        vm.expectEmit(true, true, true, true);
        emit NotificationReceiverUpdate(newAddr);

        mgm.setNotificationReceiver(newAddr);

        assertEq(address(newAddr), address(mgm.notificationReceiver()), "new notificationReceiver");
    }

    function test_setNotificationReceiver_revert() public {
        vm.expectRevert(XSiloManagement.NoChange.selector);
        mgm.setNotificationReceiver(INotificationReceiver(address(0)));
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_setStream
    */
    function test_setStream() public {
        Stream newAddr = Stream(makeAddr("new Stream"));

        vm.expectEmit(true, true, true, true);
        emit StreamUpdate(newAddr);

        mgm.setStream(newAddr);

        assertEq(address(newAddr), address(mgm.stream()), "new Stream");
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_setStream_revert
    */
    function test_setStream_revert() public {
        vm.expectRevert(XSiloManagement.NoChange.selector);
        mgm.setStream(Stream(address(0)));
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_setStream_onlyOwner
    */
    function test_setStream_onlyOwner() public {
        address someAddress = makeAddr("someAddress");

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, someAddress));
        vm.prank(someAddress);
        mgm.setStream(Stream(address(0)));
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_setNotificationReceiver_onlyOwner
    */
    function test_setNotificationReceiver_onlyOwner() public {
        address someAddress = makeAddr("someAddress");

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, someAddress));
        vm.prank(someAddress);
        mgm.setNotificationReceiver(INotificationReceiver(address(0)));
    }
}
