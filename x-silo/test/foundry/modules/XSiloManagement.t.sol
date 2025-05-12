// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

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
}
