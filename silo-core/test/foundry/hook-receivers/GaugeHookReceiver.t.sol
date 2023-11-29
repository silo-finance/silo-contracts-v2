// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {Test} from "forge-std/Test.sol";
import {Ownable2StepUpgradeable} from "openzeppelin-contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

import {GaugeHookReceiver} from "silo-core/contracts/utils/hook-receivers/gauge/GaugeHookReceiver.sol";
import {IGaugeHookReceiver} from "silo-core/contracts/utils/hook-receivers/gauge/interfaces/IGaugeHookReceiver.sol";
import {IHookReceiversFactory} from "silo-core/contracts/utils/hook-receivers/interfaces/IHookReceiversFactory.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IGaugeLike as IGauge} from "silo-core/contracts/utils/hook-receivers/gauge/interfaces/IGaugeLike.sol";
import {HookReceiversFactory} from "silo-core/contracts/utils/hook-receivers/HookReceiversFactory.sol";

import {GaugeHookReceiverDeploy} from "silo-core/deploy/GaugeHookReceiverDeploy.s.sol";
import {HookReceiversFactoryDeploy} from "../../../deploy/HookReceiversFactoryDeploy.s.sol";
import {IHookReceiversFactory} from "../../../contracts/utils/hook-receivers/interfaces/IHookReceiversFactory.sol";
import {TransferOwnership} from  "../_common/TransferOwnership.sol";

// FOUNDRY_PROFILE=core forge test -vv --ffi --mc GaugeHookReceiverTest
contract GaugeHookReceiverTest is Test, TransferOwnership {
    IHookReceiversFactory internal _hookReceiverFactory;
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

        HookReceiversFactoryDeploy factoryDeploy = new HookReceiversFactoryDeploy();
        factoryDeploy.disableDeploymentsSync();

        IGaugeHookReceiver gaugeHookReceiver = deploy.run();
        _hookReceiverFactory = factoryDeploy.run();

        IHookReceiversFactory.HookReceivers memory hooks;
        hooks.collateralHookReceiver0 = address(gaugeHookReceiver);

        _hookReceiver = IGaugeHookReceiver(_hookReceiverFactory.create(hooks).collateralHookReceiver0);
    }

    function testInitializationParamsValidation() public {
        vm.expectRevert(abi.encodePacked(IGaugeHookReceiver.OwnerIsZeroAddress.selector));
        _hookReceiver.initialize(address(0), IShareToken(_shareToken));

        // Revert without reason as `_shareToken` do not have `hookReceiver()` fn
        vm.expectRevert();
        _hookReceiver.initialize(_dao, IShareToken(_shareToken));

        vm.mockCall(
            _shareToken,
            abi.encodePacked(IShareToken.hookReceiver.selector),
            abi.encode(address(1)) // an invalid hook receiver
        );

        vm.expectRevert(IGaugeHookReceiver.InvalidShareToken.selector);
        _hookReceiver.initialize(_dao, IShareToken(_shareToken));
    }

    // forge test -vv --ffi --mt testInitialize
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

        vm.mockCall(
            _gauge,
            abi.encodePacked(IGauge.shareToken.selector),
            abi.encode(address(_shareToken)) // valid share token
        );

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

        vm.mockCall(
            _gauge,
            abi.encodePacked(IGauge.shareToken.selector),
            abi.encode(address(1)) // invalid share token
        );

        vm.prank(_dao);
        vm.expectRevert(IGaugeHookReceiver.WrongGaugeShareToken.selector);
        _hookReceiver.setGauge(IGauge(_gauge));
    }

    function testUpdateGauge() public {
        _initializeHookReceiver();

        vm.mockCall(
            _gauge,
            abi.encodePacked(IGauge.shareToken.selector),
            abi.encode(address(_shareToken)) // valid share token
        );

        vm.mockCall(
            _gauge,
            abi.encodePacked(IGauge.is_killed.selector),
            abi.encode(false)
        );

        vm.prank(_dao);
        _hookReceiver.setGauge(IGauge(_gauge));

        vm.prank(_dao);
        vm.expectRevert(IGaugeHookReceiver.CantUpdateActiveGauge.selector);
        _hookReceiver.setGauge(IGauge(_gauge2));

        vm.mockCall(
            _gauge,
            abi.encodePacked(IGauge.is_killed.selector),
            abi.encode(true)
        );

        vm.mockCall(
            _gauge2,
            abi.encodePacked(IGauge.shareToken.selector),
            abi.encode(address(_shareToken)) // valid share token
        );

        vm.expectEmit(false, false, false, true);
        emit IGaugeHookReceiver.GaugeConfigured(_gauge2);

        vm.prank(_dao);
        _hookReceiver.setGauge(IGauge(_gauge2));
    }

    function testAfterTokenTransfer() public {
        _initializeHookReceiver();

        // will do nothing as gauge is not configured
        _hookReceiver.afterTokenTransfer(
            _sender,
            _SENDER_BAL,
            _recipient,
            _RECEPIENT_BAL,
            _TS,
            _AMOUNT
        );

        _setGauge();

        vm.expectRevert(IGaugeHookReceiver.Unauthorized.selector); // only share token
        _hookReceiver.afterTokenTransfer(
            _sender,
            _SENDER_BAL,
            _recipient,
            _RECEPIENT_BAL,
            _TS,
            _AMOUNT
        );

        vm.prank(_shareToken);
        _hookReceiver.afterTokenTransfer(
            _sender,
            _SENDER_BAL,
            _recipient,
            _RECEPIENT_BAL,
            _TS,
            _AMOUNT
        );

        vm.mockCall(
            _gauge,
            abi.encodePacked(IGauge.is_killed.selector),
            abi.encode(true)
        );

        // will do nothing as gauge is killed
        _hookReceiver.afterTokenTransfer(
            _sender,
            _SENDER_BAL,
            _recipient,
            _RECEPIENT_BAL,
            _TS,
            _AMOUNT
        );
    }

    function _mockAfterTransfer() internal {
        vm.mockCall(
            _gauge,
            abi.encodeCall(
                IGauge.afterTokenTransfer,
                (
                    _sender,
                    _SENDER_BAL,
                    _recipient,
                    _RECEPIENT_BAL,
                    _TS
                )
            ),
            abi.encode(true)
        );
    }

    function _setGauge() internal {
        vm.mockCall(
            _gauge,
            abi.encodePacked(IGauge.shareToken.selector),
            abi.encode(address(_shareToken)) // valid share token
        );

        vm.mockCall(
            _gauge,
            abi.encodePacked(IGauge.is_killed.selector),
            abi.encode(false)
        );

        vm.prank(_dao);
        _hookReceiver.setGauge(IGauge(_gauge));
    }

    function _initializeHookReceiver() internal {
        vm.mockCall(
            _shareToken,
            abi.encodePacked(IShareToken.hookReceiver.selector),
            abi.encode(address(_hookReceiver)) // valid hook receiver
        );

        _hookReceiver.initialize(_dao, IShareToken(_shareToken));
    }
}
