// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {Test} from "forge-std/Test.sol";
import {Ownable2StepUpgradeable} from "openzeppelin-contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

import {GaugeHookReceiver} from "silo-core/contracts/utils/hook-receivers/gauge/GaugeHookReceiver.sol";
import {IGaugeHookReceiver} from "silo-core/contracts/utils/hook-receivers/gauge/interfaces/IGaugeHookReceiver.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IGaugeLike as IGauge} from "silo-core/contracts/utils/hook-receivers/gauge/interfaces/IGaugeLike.sol";

import {GaugeHookReceiverDeploy} from "silo-core/deploy/GaugeHookReceiverDeploy.s.sol";
import {TransferOwnership} from  "../_common/TransferOwnership.sol";


// FOUNDRY_PROFILE=core-test forge test -vv --ffi --mc GaugeHookReceiverTest
contract GaugeHookReceiverTest is Test, TransferOwnership {
    IGaugeHookReceiver internal _hookReceiver;

    uint256 internal constant _SENDER_BAL = 1;
    uint256 internal constant _RECEPIENT_BAL = 1;
    uint256 internal constant _TS = 1;
    uint256 internal constant _AMOUNT = 0;

    address internal _sender = makeAddr("Sender");
    address internal _recipient = makeAddr("Recepient");
    address internal _dao = makeAddr("DAO");
    address internal _shareToken = makeAddr("Share token");
    address internal _gauge = makeAddr("Gauge");
    address internal _gauge2 = makeAddr("Gauge2");

    event GaugeConfigured(address gauge);

    function setUp() public {
        GaugeHookReceiverDeploy deploy = new GaugeHookReceiverDeploy();
        deploy.disableDeploymentsSync();

        IGaugeHookReceiver gaugeHookReceiver = deploy.run();

        _hookReceiver = IGaugeHookReceiver(makeAddr("collateralHookReceiver0"));
    }

    // forge test -vvv --mt testInitializationParamsValidation
    function testInitializationParamsValidation() public {
        vm.expectRevert(abi.encodePacked(IGaugeHookReceiver.OwnerIsZeroAddress.selector));
        _hookReceiver.initialize(address(0), IShareToken(_shareToken));

        // Revert without reason as `_shareToken` do not have `hookReceiver()` fn
        vm.expectRevert();
        _hookReceiver.initialize(_dao, IShareToken(_shareToken));

        bytes memory data = abi.encodePacked(IShareToken.hookReceiver.selector);
        vm.mockCall(_shareToken, data, abi.encode(address(1))); // an invalid hook receiver
        vm.expectCall(_shareToken, data);

        vm.expectRevert(IGaugeHookReceiver.InvalidShareToken.selector);
        _hookReceiver.initialize(_dao, IShareToken(_shareToken));
    }

    // forge test -vv --mt testInitialize
    function testInitialize() public {
        _initializeHookReceiver();

        assertEq(
            _dao,
            Ownable2StepUpgradeable(address(_hookReceiver)).owner(),
            "Invalid owner after initialization"
        );

        assertEq(
            _shareToken,
            address(GaugeHookReceiver(address(_hookReceiver)).shareToken()),
            "Invalid share token after initialization"
        );
    }

    // forge test -vv --ffi --mt test_HookReceiver_transferOwnership
    function test_HookReceiver_transferOwnership() public {
        _initializeHookReceiver();

        assertTrue(_test_transfer2StepOwnership(address(_hookReceiver), _dao));
    }

    function testReinitialization() public {
        _initializeHookReceiver();

        vm.expectRevert("Initializable: contract is already initialized");
        _hookReceiver.initialize(_dao, IShareToken(_shareToken));

        vm.expectRevert("Initializable: contract is already initialized");
        _hookReceiver.initialize(address(1), IShareToken(address(1)));
    }

    function testSetGaugePermissions() public {
        _initializeHookReceiver();

        vm.expectRevert("Ownable: caller is not the owner");
        _hookReceiver.setGauge(IGauge(_gauge));

        bytes memory data = abi.encodePacked(IGauge.share_token.selector);
        vm.mockCall(_gauge, data, abi.encode(address(_shareToken))); // valid share token
        vm.expectCall(_gauge, data);

        vm.expectEmit(false, false, false, true);
        emit IGaugeHookReceiver.GaugeConfigured(_gauge);

        vm.prank(_dao);
        _hookReceiver.setGauge(IGauge(_gauge));
    }

    function testSetGaugeValidation() public {
        _initializeHookReceiver();

        // Revert without reason as `_gauge` do not have `shareToken()` fn
        vm.expectRevert();
        vm.prank(_dao);
        _hookReceiver.setGauge(IGauge(_gauge));

        bytes memory data = abi.encodePacked(IGauge.share_token.selector);
        vm.mockCall(_gauge, data, abi.encode(address(1))); // invalid share token
        vm.expectCall(_gauge, data);

        vm.prank(_dao);
        vm.expectRevert(IGaugeHookReceiver.WrongGaugeShareToken.selector);
        _hookReceiver.setGauge(IGauge(_gauge));
    }

    function testUpdateGauge() public {
        _initializeHookReceiver();

        bytes memory data = abi.encodePacked(IGauge.share_token.selector);
        vm.mockCall(_gauge, data, abi.encode(address(_shareToken))); // valid share token
        vm.expectCall(_gauge, data);

        bytes memory data2 = abi.encodePacked(IGauge.is_killed.selector);
        vm.mockCall(_gauge, data2, abi.encode(false));
        vm.expectCall(_gauge, data2);

        vm.prank(_dao);
        _hookReceiver.setGauge(IGauge(_gauge));

        vm.prank(_dao);
        vm.expectRevert(IGaugeHookReceiver.CantUpdateActiveGauge.selector);
        _hookReceiver.setGauge(IGauge(_gauge2));

        bytes memory data3 = abi.encodePacked(IGauge.is_killed.selector);
        vm.mockCall(_gauge, data3, abi.encode(true));
        vm.expectCall(_gauge, data3);

        bytes memory data4 = abi.encodePacked(IGauge.share_token.selector);
        vm.mockCall(_gauge2, data4, abi.encode(address(_shareToken))); // valid share token
        vm.expectCall(_gauge2, data4);

        vm.expectEmit(false, false, false, true);
        emit IGaugeHookReceiver.GaugeConfigured(_gauge2);

        vm.prank(_dao);
        _hookReceiver.setGauge(IGauge(_gauge2));
    }

    // forge test -vvv --mt testAfterTokenTransfer
    function testAfterTokenTransfer() public {
        _initializeHookReceiver();

        vm.expectRevert(IGaugeHookReceiver.Unauthorized.selector); // only share token
        _hookReceiver.afterTokenTransfer(
            _sender,
            _SENDER_BAL,
            _recipient,
            _RECEPIENT_BAL,
            _TS,
            _AMOUNT
        );

        // will do nothing as gauge is not configured
        vm.prank(_shareToken);
        _hookReceiver.afterTokenTransfer(
            _sender,
            _SENDER_BAL,
            _recipient,
            _RECEPIENT_BAL,
            _TS,
            _AMOUNT
        );

        _setGauge();

        // will do nothing when gauge is killed
        _mockGaugeIsKilled(true);
        vm.prank(_shareToken);
        _hookReceiver.afterTokenTransfer(
            _sender,
            _SENDER_BAL,
            _recipient,
            _RECEPIENT_BAL,
            _TS,
            _AMOUNT
        );

        // gauge is set and not killed, notification will be send
        _mockGaugeIsKilled(false);
        _mockGaugeAfterTransfer();
        vm.prank(_shareToken);
        _hookReceiver.afterTokenTransfer(
            _sender,
            _SENDER_BAL,
            _recipient,
            _RECEPIENT_BAL,
            _TS,
            _AMOUNT
        );
    }

    function _mockGaugeAfterTransfer() internal {
        bytes memory data = abi.encodeCall(
            IGauge.afterTokenTransfer,
            (
                _sender,
                _SENDER_BAL,
                _recipient,
                _RECEPIENT_BAL,
                _TS
            )
        );

        vm.mockCall(_gauge, data, abi.encode(false));
        vm.expectCall(_gauge, data);
    }

    function _setGauge() internal {
        bytes memory data = abi.encodePacked(IGauge.share_token.selector);
        vm.mockCall(_gauge, data, abi.encode(address(_shareToken))); // valid share token
        vm.expectCall(_gauge, data);

        vm.prank(_dao);
        _hookReceiver.setGauge(IGauge(_gauge));
    }

    function _mockGaugeIsKilled(bool _killed) internal {
        bytes memory data2 = abi.encodePacked(IGauge.is_killed.selector); // selector:0x9c868ac0
        vm.mockCall(_gauge, data2, abi.encode(_killed));
        vm.expectCall(_gauge, data2);
    }

    function _initializeHookReceiver() internal {
        // IShareToken.hookReceiver.selector: 0x8fea8062
        bytes memory data = abi.encodePacked(IShareToken.hookReceiver.selector);

        vm.mockCall(_shareToken, data, abi.encode(address(_hookReceiver))); // valid hook receiver
        vm.expectCall(_shareToken, data);

        _hookReceiver.initialize(_dao, IShareToken(_shareToken));
    }
}
