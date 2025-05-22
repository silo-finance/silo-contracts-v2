// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {Initializable} from "openzeppelin5/proxy/utils/Initializable.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";
import {IHookReceiver} from "silo-core/contracts/interfaces/IHookReceiver.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";

import {IIncentivesClaimingLogic} from "silo-vaults/contracts/interfaces/IIncentivesClaimingLogic.sol";
import {INotificationReceiver} from "silo-vaults/contracts/interfaces/INotificationReceiver.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IIncentiveHook} from "silo-core/contracts/interfaces/IIncentiveHook.sol";
import {MockClaimingLogic} from "silo-core/test/foundry/_mocks/MockClaimingLogic.sol";
import {MockClaimingLogicReverts} from "silo-core/test/foundry/_mocks/MockClaimingLogicReverts.sol";

import {VeSiloContracts} from "ve-silo/common/VeSiloContracts.sol";

import {SiloLittleHelper} from  "../../../_common/SiloLittleHelper.sol";
import {TransferOwnership} from  "../../../_common/TransferOwnership.sol";

// FOUNDRY_PROFILE=core_test forge test -vv --ffi --mc IncentiveHookTest
contract IncentiveHookTest is SiloLittleHelper, Test, TransferOwnership {
    IIncentiveHook internal _hookReceiver;
    ISiloConfig internal _siloConfig;

    address internal _dao = makeAddr("DAO");
    address internal _incentivesClaimingLogic1 = makeAddr("IncentivesClaimingLogic1");
    address internal _incentivesClaimingLogic2 = makeAddr("IncentivesClaimingLogic2");
    address internal _notificationReceiver1 = makeAddr("NotificationReceiver1");
    address internal _notificationReceiver2 = makeAddr("NotificationReceiver2");
    IShareToken internal _shareToken1;
    IShareToken internal _shareToken2;

    // Mocks for beforeAction tests
    MockClaimingLogic internal mockLogic1;
    MockClaimingLogic internal mockLogic2;

    MockClaimingLogicReverts internal mockLogicReverts1;
    MockClaimingLogicReverts internal mockLogicReverts2;

    event IncentivesClaimingLogicAdded(ISilo indexed silo, IIncentivesClaimingLogic indexed logic);
    event IncentivesClaimingLogicRemoved(ISilo indexed silo, IIncentivesClaimingLogic indexed logic);
    event NotificationReceiverAdded(IShareToken indexed shareToken, INotificationReceiver indexed receiver);
    event NotificationReceiverRemoved(IShareToken indexed shareToken, INotificationReceiver indexed receiver);
    event FailedToClaimIncentives(address indexed silo, address claimingLogic);

    function setUp() public virtual {
        AddrLib.setAddress(VeSiloContracts.TIMELOCK_CONTROLLER, _dao);

        _siloConfig = _setUpLocalFixture(SiloConfigsNames.SILO_LOCAL_INCENTIVE_HOOK_RECEIVER);

        IHookReceiver hook = IHookReceiver(IShareToken(address(silo0)).hookSetup().hookReceiver);

        _hookReceiver = IIncentiveHook(address(hook));

        (address protectedShareToken,address collateralShareToken,) = _siloConfig.getShareTokens(address(silo0));
        _shareToken1 = IShareToken(collateralShareToken);
        _shareToken2 = IShareToken(protectedShareToken);

        // Deploy mocks for tests that need them
        mockLogic1 = new MockClaimingLogic();
        mockLogic2 = new MockClaimingLogic();

        mockLogicReverts1 = new MockClaimingLogicReverts();
        mockLogicReverts2 = new MockClaimingLogicReverts();
    }

    // FOUNDRY_PROFILE=core_test forge test --ffi -vvv --mt testReInitialization
    function testReInitialization() public {
        address hookReceiverImpl = AddrLib.getAddress(SiloCoreContracts.SILO_HOOK_V1);

        bytes memory data = abi.encode(_dao);

        // Implementation is not initializable
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        IHookReceiver(hookReceiverImpl).initialize(ISiloConfig(address(0)), data);

        // `SILO_HOOK_V1` hook receiver can't be re-initialized
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        IHookReceiver(address(_hookReceiver)).initialize(ISiloConfig(address(0)), data);
    }

    // FOUNDRY_PROFILE=core_test forge test -vvv --ffi --mt testHookReceiverInitialization
    function testHookReceiverInitialization() public view {
        (address silo0, address silo1) = _siloConfig.getSilos();

        _testHookReceiverInitializationForSilo(silo0);
        _testHookReceiverInitializationForSilo(silo1);
    }

    // FOUNDRY_PROFILE=core_test forge test -vvv --ffi --mt testIncentiveHookTransferOwnership
    function testIncentiveHookTransferOwnership() public {
        assertTrue(_test_transfer2StepOwnership(address(_hookReceiver), _dao));
    }

    // FOUNDRY_PROFILE=core_test forge test -vvv --ffi --mt testIncentiveHookPermissions
    function testIncentiveHookPermissions() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        _hookReceiver.addIncentivesClaimingLogic(silo0, IIncentivesClaimingLogic(address(0)));

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        _hookReceiver.removeIncentivesClaimingLogic(silo0, IIncentivesClaimingLogic(address(0)));

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        _hookReceiver.addNotificationReceiver(_shareToken1, INotificationReceiver(address(0)));

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        _hookReceiver.removeNotificationReceiver(_shareToken1, INotificationReceiver(address(0)), true);
    }

    // FOUNDRY_PROFILE=core_test forge test -vvv --ffi --mt test_addIncentivesClaimingLogic
    function test_addIncentivesClaimingLogic() public {
        vm.prank(_dao);
        vm.expectEmit();
        emit IncentivesClaimingLogicAdded(silo0, IIncentivesClaimingLogic(_incentivesClaimingLogic1));
        _hookReceiver.addIncentivesClaimingLogic(silo0, IIncentivesClaimingLogic(_incentivesClaimingLogic1));

        vm.prank(_dao);
        vm.expectEmit();
        emit IncentivesClaimingLogicAdded(silo0, IIncentivesClaimingLogic(_incentivesClaimingLogic2));
        _hookReceiver.addIncentivesClaimingLogic(silo0, IIncentivesClaimingLogic(_incentivesClaimingLogic2));

        address[] memory incentivesClaimingLogics = _hookReceiver.getIncentivesClaimingLogics(silo0);
        assertEq(incentivesClaimingLogics.length, 2);
        assertEq(incentivesClaimingLogics[0], _incentivesClaimingLogic1);
        assertEq(incentivesClaimingLogics[1], _incentivesClaimingLogic2);
    }

    // FOUNDRY_PROFILE=core_test forge test -vvv --ffi --mt test_addIncentivesClaimingLogic_alreadyAdded
    function test_addIncentivesClaimingLogic_alreadyAdded() public {
        vm.prank(_dao);
        _hookReceiver.addIncentivesClaimingLogic(silo0, IIncentivesClaimingLogic(_incentivesClaimingLogic1));

        vm.prank(_dao);
        vm.expectRevert(IIncentiveHook.ClaimingLogicAlreadyAdded.selector);
        _hookReceiver.addIncentivesClaimingLogic(silo0, IIncentivesClaimingLogic(_incentivesClaimingLogic1));
    }

    // FOUNDRY_PROFILE=core_test forge test -vvv --ffi --mt test_addIncentivesClaimingLogic_invalidSilo
    function test_addIncentivesClaimingLogic_invalidSilo() public {
        vm.prank(_dao);
        ISilo invalidSilo = ISilo(makeAddr("InvalidSilo"));
        vm.expectRevert(IIncentiveHook.InvalidSilo.selector);
        _hookReceiver.addIncentivesClaimingLogic(invalidSilo, IIncentivesClaimingLogic(_incentivesClaimingLogic1));
    }

    // FOUNDRY_PROFILE=core_test forge test -vvv --ffi --mt test_addIncentivesClaimingLogic_zeroAddress
    function test_addIncentivesClaimingLogic_zeroAddress() public {
        vm.prank(_dao);
        vm.expectRevert(IIncentiveHook.ZeroAddress.selector);
        _hookReceiver.addIncentivesClaimingLogic(silo0, IIncentivesClaimingLogic(address(0)));
    }

    // FOUNDRY_PROFILE=core_test forge test -vvv --ffi --mt test_addIncentivesClaimingLogic_configuresHooks
    function test_addIncentivesClaimingLogic_configuresHooks() public {
        // Ensure no hooks are set initially for silo0's before hooks
        (uint24 hooksBefore,) = IHookReceiver(address(_hookReceiver)).hookReceiverConfig(address(silo0));
        assertEq(uint256(hooksBefore), 0, "Initial hooksBefore should be 0");
        // hooksAfter might be configured by addNotificationReceiver tests if they run prior,
        // so we only focus on hooksBefore which is solely configured by addIncentivesClaimingLogic.

        vm.prank(_dao);
        _hookReceiver.addIncentivesClaimingLogic(silo0, IIncentivesClaimingLogic(_incentivesClaimingLogic1));

        uint256 expectedHooksBefore = Hook.DEPOSIT |
            Hook.WITHDRAW |
            Hook.BORROW |
            Hook.BORROW_SAME_ASSET |
            Hook.REPAY |
            Hook.TRANSITION_COLLATERAL |
            Hook.SWITCH_COLLATERAL |
            Hook.LIQUIDATION |
            Hook.FLASH_LOAN;

        (hooksBefore,) = IHookReceiver(address(_hookReceiver)).hookReceiverConfig(address(silo0));
        assertEq(uint256(hooksBefore), expectedHooksBefore, "hooksBefore not configured correctly");
    }

    // FOUNDRY_PROFILE=core_test forge test -vvv --ffi --mt test_removeIncentivesClaimingLogic
    function test_removeIncentivesClaimingLogic() public {
        vm.startPrank(_dao);
        _hookReceiver.addIncentivesClaimingLogic(silo0, IIncentivesClaimingLogic(_incentivesClaimingLogic1));
        _hookReceiver.addIncentivesClaimingLogic(silo0, IIncentivesClaimingLogic(_incentivesClaimingLogic2));

        vm.expectEmit();
        emit IncentivesClaimingLogicRemoved(silo0, IIncentivesClaimingLogic(_incentivesClaimingLogic1));
        _hookReceiver.removeIncentivesClaimingLogic(silo0, IIncentivesClaimingLogic(_incentivesClaimingLogic1));

        address[] memory incentivesClaimingLogics = _hookReceiver.getIncentivesClaimingLogics(silo0);
        assertEq(incentivesClaimingLogics.length, 1);
        assertEq(incentivesClaimingLogics[0], _incentivesClaimingLogic2);

        vm.expectEmit();
        emit IncentivesClaimingLogicRemoved(silo0, IIncentivesClaimingLogic(_incentivesClaimingLogic2));
        _hookReceiver.removeIncentivesClaimingLogic(silo0, IIncentivesClaimingLogic(_incentivesClaimingLogic2));

        vm.stopPrank();

        incentivesClaimingLogics = _hookReceiver.getIncentivesClaimingLogics(silo0);
        assertEq(incentivesClaimingLogics.length, 0);
    }

    // FOUNDRY_PROFILE=core_test forge test -vvv --ffi --mt test_removeIncentivesClaimingLogic_notAdded
    function test_removeIncentivesClaimingLogic_notAdded() public {
        vm.startPrank(_dao);
        vm.expectRevert(IIncentiveHook.ClaimingLogicNotAdded.selector);
        _hookReceiver.removeIncentivesClaimingLogic(silo0, IIncentivesClaimingLogic(_incentivesClaimingLogic1));
        vm.stopPrank();
    }

    // FOUNDRY_PROFILE=core_test forge test -vvv --ffi --mt test_removeIncentivesClaimingLogic_invalidSilo
    function test_removeIncentivesClaimingLogic_invalidSilo() public {
        vm.prank(_dao);
        // First, add a logic to a valid silo to ensure the function doesn't revert for other reasons.
        _hookReceiver.addIncentivesClaimingLogic(silo0, IIncentivesClaimingLogic(_incentivesClaimingLogic1));

        ISilo invalidSilo = ISilo(makeAddr("InvalidSilo"));
        // This will revert with `ClaimingLogicNotAdded` because the `EnumerableSet` for `invalidSilo` will be empty.
        vm.prank(_dao);
        vm.expectRevert(IIncentiveHook.ClaimingLogicNotAdded.selector);
        _hookReceiver.removeIncentivesClaimingLogic(invalidSilo, IIncentivesClaimingLogic(_incentivesClaimingLogic1));
    }

    // FOUNDRY_PROFILE=core_test forge test -vvv --ffi --mt test_addNotificationReceiver
    function test_addNotificationReceiver() public {
        vm.prank(_dao);
        vm.expectEmit();
        emit NotificationReceiverAdded(_shareToken1, INotificationReceiver(_notificationReceiver1));
        _hookReceiver.addNotificationReceiver(_shareToken1, INotificationReceiver(_notificationReceiver1));

        vm.prank(_dao);
        vm.expectEmit();
        emit NotificationReceiverAdded(_shareToken2, INotificationReceiver(_notificationReceiver2));
        _hookReceiver.addNotificationReceiver(_shareToken2, INotificationReceiver(_notificationReceiver2));

        address[] memory notificationReceivers = _hookReceiver.getNotificationReceivers(_shareToken1);
        assertEq(notificationReceivers.length, 1);
        assertEq(notificationReceivers[0], _notificationReceiver1);

        notificationReceivers = _hookReceiver.getNotificationReceivers(_shareToken2);
        assertEq(notificationReceivers.length, 1);
        assertEq(notificationReceivers[0], _notificationReceiver2);
    }

    // FOUNDRY_PROFILE=core_test forge test -vvv --ffi --mt test_addNotificationReceiver_alreadyAdded
    function test_addNotificationReceiver_alreadyAdded() public {
        vm.prank(_dao);
        _hookReceiver.addNotificationReceiver(_shareToken1, INotificationReceiver(_notificationReceiver1));

        vm.prank(_dao);
        vm.expectRevert(IIncentiveHook.NotificationReceiverAlreadyAdded.selector);
        _hookReceiver.addNotificationReceiver(_shareToken1, INotificationReceiver(_notificationReceiver1));
    }

    // FOUNDRY_PROFILE=core_test forge test -vvv --ffi --mt test_removeNotificationReceiver_allProgramsNotStopped
    function test_removeNotificationReceiver_allProgramsNotStopped() public {
        vm.prank(_dao);
        _hookReceiver.addNotificationReceiver(_shareToken1, INotificationReceiver(_notificationReceiver1));

        vm.prank(_dao);
        vm.expectRevert(IIncentiveHook.AllProgramsNotStopped.selector);
        _hookReceiver.removeNotificationReceiver(_shareToken1, INotificationReceiver(_notificationReceiver1), false);
    }

    // FOUNDRY_PROFILE=core_test forge test -vvv --ffi --mt test_removeNotificationReceiver_notAdded
    function test_removeNotificationReceiver_notAdded() public {
        vm.startPrank(_dao);
        vm.expectRevert(IIncentiveHook.NotificationReceiverNotAdded.selector);
        _hookReceiver.removeNotificationReceiver(_shareToken1, INotificationReceiver(_notificationReceiver1), true);
        vm.stopPrank();
    }

    // FOUNDRY_PROFILE=core_test forge test -vvv --ffi --mt test_removeNotificationReceiver
    function test_removeNotificationReceiver() public {
        vm.startPrank(_dao);
        _hookReceiver.addNotificationReceiver(_shareToken1, INotificationReceiver(_notificationReceiver1));
        _hookReceiver.addNotificationReceiver(_shareToken2, INotificationReceiver(_notificationReceiver2));

        vm.expectEmit();
        emit NotificationReceiverRemoved(_shareToken1, INotificationReceiver(_notificationReceiver1));
        _hookReceiver.removeNotificationReceiver(_shareToken1, INotificationReceiver(_notificationReceiver1), true);

        address[] memory notificationReceivers = _hookReceiver.getNotificationReceivers(_shareToken1);
        assertEq(notificationReceivers.length, 0);

        notificationReceivers = _hookReceiver.getNotificationReceivers(_shareToken2);
        assertEq(notificationReceivers.length, 1);
        assertEq(notificationReceivers[0], _notificationReceiver2);

        vm.expectEmit();
        emit NotificationReceiverRemoved(_shareToken2, INotificationReceiver(_notificationReceiver2));
        _hookReceiver.removeNotificationReceiver(_shareToken2, INotificationReceiver(_notificationReceiver2), true);

        notificationReceivers = _hookReceiver.getNotificationReceivers(_shareToken2);
        assertEq(notificationReceivers.length, 0);

        vm.stopPrank();
    }

    // FOUNDRY_PROFILE=core_test forge test -vvv --ffi --mt test_getIncentivesClaimingLogics_empty
    function test_getIncentivesClaimingLogics_empty() public {
        address[] memory logics = _hookReceiver.getIncentivesClaimingLogics(silo0);
        assertEq(logics.length, 0, "Logics should be empty");

        logics = _hookReceiver.getIncentivesClaimingLogics(ISilo(makeAddr("NonExistentSilo")));
         assertEq(logics.length, 0, "Logics for non-existent silo should be empty");
    }

    // FOUNDRY_PROFILE=core_test forge test -vvv --ffi --mt test_getNotificationReceivers_empty
    function test_getNotificationReceivers_empty() public {
        address[] memory receivers = _hookReceiver.getNotificationReceivers(_shareToken1);
        assertEq(receivers.length, 0, "Receivers for shareToken1 should be empty");

        IShareToken nonExistentShareToken = IShareToken(makeAddr("NonExistentShareToken"));
        receivers = _hookReceiver.getNotificationReceivers(nonExistentShareToken);
        assertEq(receivers.length, 0, "Receivers for non-existent shareToken should be empty");
    }

    // FOUNDRY_PROFILE=core_test forge test -vvv --ffi --mt test_beforeAction_onlySiloModifier
    function test_beforeAction_onlySiloModifier() public {
        vm.expectRevert(IHookReceiver.OnlySilo.selector);
        IHookReceiver(address(_hookReceiver)).beforeAction(address(silo0), Hook.DEPOSIT, bytes(""));
    }

    // FOUNDRY_PROFILE=core_test forge test -vvv --ffi --mt test_beforeAction_noClaimingLogics
    function test_beforeAction_noClaimingLogics() public {
        // Call beforeAction
        vm.prank(address(silo0));
        IHookReceiver(address(_hookReceiver)).beforeAction(address(silo0), Hook.DEPOSIT, bytes(""));
    }

    // FOUNDRY_PROFILE=core_test forge test -vvv --ffi --mt test_beforeAction_singleClaimingLogic_success
    function test_beforeAction_singleClaimingLogic_success() public {
        vm.prank(_dao);
        _hookReceiver.addIncentivesClaimingLogic(silo0, IIncentivesClaimingLogic(address(mockLogic1)));

        // Expect event from mock logic via delegatecall from silo0
        vm.expectEmit(true, true, true, true, address(silo0));
        emit MockClaimingLogic.ClaimRewardsCalled(address(silo0), address(mockLogic1), address(_hookReceiver), 1);

        vm.prank(address(silo0));
        IHookReceiver(address(_hookReceiver)).beforeAction(address(silo0), Hook.DEPOSIT, bytes(""));
    }

    // FOUNDRY_PROFILE=core_test forge test -vvv --ffi --mt test_beforeAction_multipleClaimingLogics_success
    function test_beforeAction_multipleClaimingLogics_success() public {
        vm.startPrank(_dao);
        _hookReceiver.addIncentivesClaimingLogic(silo0, IIncentivesClaimingLogic(address(mockLogic1)));
        _hookReceiver.addIncentivesClaimingLogic(silo0, IIncentivesClaimingLogic(address(mockLogic2)));
        vm.stopPrank();

        // Expect events from both mock logics
        vm.expectEmit(true, true, true, true, address(silo0));
        emit MockClaimingLogic.ClaimRewardsCalled(address(silo0), address(mockLogic1), address(_hookReceiver), 1);
        vm.expectEmit(true, true, true, true, address(silo0));
        emit MockClaimingLogic.ClaimRewardsCalled(address(silo0), address(mockLogic2), address(_hookReceiver), 1);

        vm.prank(address(silo0));
        IHookReceiver(address(_hookReceiver)).beforeAction(address(silo0), Hook.WITHDRAW, bytes(""));
    }

    // FOUNDRY_PROFILE=core_test forge test -vvv --ffi --mt test_beforeAction_singleClaimingLogic_reverts
    function test_beforeAction_singleClaimingLogic_reverts() public {
        vm.prank(_dao);
        _hookReceiver.addIncentivesClaimingLogic(silo0, IIncentivesClaimingLogic(address(mockLogicReverts1)));
        
        vm.expectEmit(true, true, true, true, address(_hookReceiver));
        emit FailedToClaimIncentives(address(silo0), address(mockLogicReverts1));

        vm.prank(address(silo0));
        IHookReceiver(address(_hookReceiver)).beforeAction(address(silo0), Hook.BORROW, bytes(""));
    }

    // FOUNDRY_PROFILE=core_test forge test -vvv --ffi --mt test_beforeAction_multipleClaimingLogics_firstReverts
    function test_beforeAction_multipleClaimingLogics_firstReverts() public {
        vm.startPrank(_dao);
        _hookReceiver.addIncentivesClaimingLogic(silo0, IIncentivesClaimingLogic(address(mockLogicReverts1)));
        _hookReceiver.addIncentivesClaimingLogic(silo0, IIncentivesClaimingLogic(address(mockLogic2)));
        vm.stopPrank();

        vm.expectEmit(true, true, true, true, address(_hookReceiver));
        emit FailedToClaimIncentives(address(silo0), address(mockLogicReverts1));

        vm.prank(address(silo0));
        IHookReceiver(address(_hookReceiver)).beforeAction(address(silo0), Hook.REPAY, bytes(""));
    }

    // FOUNDRY_PROFILE=core_test forge test -vvv --ffi --mt test_beforeAction_multipleClaimingLogics_secondReverts
    function test_beforeAction_multipleClaimingLogics_secondReverts() public {
        vm.startPrank(_dao);
        _hookReceiver.addIncentivesClaimingLogic(silo0, IIncentivesClaimingLogic(address(mockLogic1)));
        _hookReceiver.addIncentivesClaimingLogic(silo0, IIncentivesClaimingLogic(address(mockLogicReverts2)));
        vm.stopPrank();
        
        // Expect call to mockLogic1 to succeed
        vm.expectEmit(true, true, true, true, address(silo0));
        emit MockClaimingLogic.ClaimRewardsCalled(address(silo0), address(mockLogic1), address(_hookReceiver), 1);

        vm.expectEmit(true, true, true, true, address(_hookReceiver));
        emit FailedToClaimIncentives(address(silo0), address(mockLogicReverts2));

        vm.prank(address(silo0));
        IHookReceiver(address(_hookReceiver)).beforeAction(address(silo0), Hook.LIQUIDATION, bytes(""));
    }

    // FOUNDRY_PROFILE=core_test forge test -vvv --ffi --mt test_beforeAction_onlySiloOrShareTokenModifier
    function test_beforeAction_onlySiloOrShareTokenModifier() public {
        vm.expectRevert(IHookReceiver.OnlySiloOrShareToken.selector);
        IHookReceiver(address(_hookReceiver)).beforeAction(address(silo0), Hook.DEPOSIT, bytes(""));
    }

    /*
     FOUNDRY_PROFILE=core_test forge test -vvv --ffi \
        --mt test_afterAction_onlySiloOrShareTokenModifier_success_without_config
    */
    function test_afterAction_onlySiloOrShareTokenModifier_success_without_config() public {
        vm.prank(address(silo0));
        IHookReceiver(address(_hookReceiver)).afterAction(address(silo0), Hook.DEPOSIT, bytes(""));

        vm.prank(address(silo1));
        IHookReceiver(address(_hookReceiver)).afterAction(address(silo1), Hook.DEPOSIT, bytes(""));

        address protectedCollateralShareToken;
        address collateralShareToken;
        address debtShareToken;

        (protectedCollateralShareToken, collateralShareToken, debtShareToken) =
            _siloConfig.getShareTokens(address(silo0));

        vm.prank(protectedCollateralShareToken);
        IHookReceiver(address(_hookReceiver)).afterAction(address(silo0), Hook.DEPOSIT, bytes(""));

        vm.prank(collateralShareToken);
        IHookReceiver(address(_hookReceiver)).afterAction(address(silo0), Hook.DEPOSIT, bytes(""));

        vm.prank(debtShareToken);
        IHookReceiver(address(_hookReceiver)).afterAction(address(silo0), Hook.DEPOSIT, bytes(""));

        (protectedCollateralShareToken, collateralShareToken, debtShareToken) =
            _siloConfig.getShareTokens(address(silo1));

        vm.prank(protectedCollateralShareToken);
        IHookReceiver(address(_hookReceiver)).afterAction(address(silo1), Hook.DEPOSIT, bytes(""));

        vm.prank(collateralShareToken);
        IHookReceiver(address(_hookReceiver)).afterAction(address(silo1), Hook.DEPOSIT, bytes(""));

        vm.prank(debtShareToken);
        IHookReceiver(address(_hookReceiver)).afterAction(address(silo1), Hook.DEPOSIT, bytes(""));
    }

    // FOUNDRY_PROFILE=core_test forge test -vvv --ffi --mt test_afterAction_multipleReceivers_success
    function test_afterAction_multipleReceivers_success() public {
        vm.prank(_dao);
        _hookReceiver.addNotificationReceiver(_shareToken1, INotificationReceiver(_notificationReceiver1));
        vm.prank(_dao);
        _hookReceiver.addNotificationReceiver(_shareToken1, INotificationReceiver(_notificationReceiver2));

        address sender = makeAddr("Sender");
        address recipient = makeAddr("Recipient");
        uint256 amount = 100;
        uint256 senderBalance = 100;
        uint256 recipientBalance = 100;
        uint256 totalSupply = 100;

        bytes memory data = abi.encodePacked(
            sender,
            recipient,
            amount,
            senderBalance,
            recipientBalance,
            totalSupply
        );

        _mocAfterTransfer(
            _notificationReceiver1,
            sender,
            recipient,
            amount,
            senderBalance,
            recipientBalance,
            totalSupply
        );

        _mocAfterTransfer(
            _notificationReceiver2,
            sender,
            recipient,
            amount,
            senderBalance,
            recipientBalance,
            totalSupply
        );

        uint256 action = Hook.COLLATERAL_TOKEN | Hook.SHARE_TOKEN_TRANSFER;

        vm.prank(address(silo0));
        IHookReceiver(address(_hookReceiver)).afterAction(address(silo0), action, data);
    }

    function _mocAfterTransfer(
        address _notificationReceiver,
        address _sender,
        address _recipient,
        uint256 _amount,
        uint256 _senderBalance,
        uint256 _recipientBalance,
        uint256 _totalSupply
    ) internal {
        bytes memory data = abi.encodeCall(
            INotificationReceiver.afterTokenTransfer,
            (
                _sender,
                _senderBalance,
                _recipient,
                _recipientBalance,
                _totalSupply,
                _amount
            )
        );

        vm.mockCall(_notificationReceiver, data, abi.encode(true));
        vm.expectCall(_notificationReceiver, data);
    }

    function _testHookReceiverInitializationForSilo(address _silo) internal view {
        IHookReceiver hookReceiver = IHookReceiver(IShareToken(address(silo0)).hookSetup().hookReceiver);

        assertEq(address(hookReceiver), address(_hookReceiver));

        (
            address collateral,
            address protected,
            address debt
        ) = _siloConfig.getShareTokens(_silo);

        _testHookReceiverForShareToken(collateral);
        _testHookReceiverForShareToken(protected);
        _testHookReceiverForShareToken(debt);
    }

    function _testHookReceiverForShareToken(address _siloShareToken) internal view {
        IShareToken.HookSetup memory hookSetup = IShareToken(_siloShareToken).hookSetup();
        assertEq(hookSetup.hookReceiver, address(_hookReceiver));
    }
}
