// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "openzeppelin5/access/Ownable.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ERC20Mock} from "openzeppelin5/mocks/token/ERC20Mock.sol";

import {XSiloManagement, INotificationReceiver, Stream} from "../../../contracts/modules/XSiloManagement.sol";
import {XSiloAndStreamDeploy} from "x-silo/deploy/XSiloAndStreamDeploy.s.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";
import {XSilo} from "x-silo/contracts/XSilo.sol";

/*
FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mc XSiloManagementTest
*/
contract XSiloManagementTest is Test {
    XSilo mgm;

    event NotificationReceiverUpdate(INotificationReceiver indexed newNotificationReceiver);
    event StreamUpdate(Stream indexed newStream);

    function setUp() public {
        AddrLib.init();
        AddrLib.setAddress(AddrKey.SILO_TOKEN_V2, address(new ERC20Mock()));
        AddrLib.setAddress(AddrKey.DAO, address(this));

        XSiloAndStreamDeploy deploy = new XSiloAndStreamDeploy();
        deploy.disableDeploymentsSync();
        (mgm,) = deploy.run();
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
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_setStream_streamWithoutBENEFICIARY
    */
    function test_setStream_streamWithoutBENEFICIARY() public {
        Stream streamWithoutBENEFICIARY = Stream(makeAddr("new Stream"));

        vm.expectRevert();
        mgm.setStream(streamWithoutBENEFICIARY);
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_setStream_NotBeneficiary
    */
    function test_setStream_NotBeneficiary() public {
        Stream stream = Stream(makeAddr("new Stream"));

        vm.mockCall(
            address(stream),
            abi.encodeWithSelector(stream.BENEFICIARY.selector),
            abi.encode(address(123))
        );

        vm.expectRevert(XSiloManagement.NotBeneficiary.selector);
        mgm.setStream(stream);
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_setStream_pass
    */
    function test_setStream_pass() public {
        Stream newStream = Stream(makeAddr("new Stream"));

        vm.mockCall(
            address(newStream),
            abi.encodeWithSelector(newStream.BENEFICIARY.selector),
            abi.encode(address(mgm))
        );

        vm.expectEmit(true, true, true, true);
        emit StreamUpdate(newStream);

        mgm.setStream(newStream);

        assertEq(address(newStream), address(mgm.stream()), "new Stream");
    }

    /*
    FOUNDRY_PROFILE=x_silo forge test -vv --ffi --mt test_setStream_revert
    */
    function test_setStream_revert() public {
        Stream currentStream = mgm.stream();
        vm.expectRevert(XSiloManagement.NoChange.selector);
        mgm.setStream(currentStream);
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
