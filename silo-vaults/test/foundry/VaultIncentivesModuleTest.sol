// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {Clones} from "openzeppelin5/proxy/Clones.sol";
import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

import {IIncentivesClaimingLogic} from "silo-vaults/contracts/interfaces/IIncentivesClaimingLogic.sol";
import {IIncentivesClaimingLogicFactory} from "silo-vaults/contracts/interfaces/IIncentivesClaimingLogicFactory.sol";
import {ErrorsLib} from "silo-vaults/contracts/libraries/ErrorsLib.sol";
import {IIncentivesClaimingLogic} from "silo-vaults/contracts/interfaces/IIncentivesClaimingLogic.sol";
import {ISiloVault, ISiloVaultBase} from "silo-vaults/contracts/interfaces/ISiloVault.sol";
import {INotificationReceiver} from "silo-vaults/contracts/interfaces/INotificationReceiver.sol";
import {VaultIncentivesModule} from "silo-vaults/contracts/incentives/VaultIncentivesModule.sol";
import {IVaultIncentivesModule} from "silo-vaults/contracts/interfaces/IVaultIncentivesModule.sol";

/*
FOUNDRY_PROFILE=vaults_tests forge test --mc VaultIncentivesModuleTest -vv
*/
contract VaultIncentivesModuleTest is Test {
    bool internal constant _ALL_PROGRAMS_STOPPED = true;
    uint256 internal _timelock = 1 days;

    VaultIncentivesModule public incentivesModule;

    address internal _solution1 = makeAddr("Solution1");
    address internal _solution2 = makeAddr("Solution2");

    IIncentivesClaimingLogicFactory internal _trustedFactory =
        IIncentivesClaimingLogicFactory(makeAddr("TrustedFactory"));

    IIncentivesClaimingLogic internal _logic1 = IIncentivesClaimingLogic(makeAddr("Logic1"));
    IIncentivesClaimingLogic internal _logic2 = IIncentivesClaimingLogic(makeAddr("Logic2"));

    IERC4626 internal _market1 = IERC4626(makeAddr("Market1"));
    IERC4626 internal _market2 = IERC4626(makeAddr("Market2"));

    address internal _deployer = makeAddr("_deployer");
    address internal _guardian = makeAddr("_guardian");
    address internal _curator = makeAddr("_curator");
    address internal _vault = makeAddr("_vault");

    event IncentivesClaimingLogicAdded(IERC4626 indexed market, IIncentivesClaimingLogic logic);
    event IncentivesClaimingLogicRemoved(IERC4626 indexed market, IIncentivesClaimingLogic logic);
    event SubmitIncentivesClaimingLogic(IERC4626 indexed market, IIncentivesClaimingLogic logic);
    event RevokePendingClaimingLogic(IERC4626 indexed market, IIncentivesClaimingLogic logic);
    event NotificationReceiverAdded(address notificationReceiver);
    event NotificationReceiverRemoved(address notificationReceiver);
    event TrustedFactorySubmitted(IIncentivesClaimingLogicFactory factory);
    event TrustedFactoryAdded(IIncentivesClaimingLogicFactory factory);
    event TrustedFactoryRevoked(IIncentivesClaimingLogicFactory factory);
    event TrustedFactoryRemoved(IIncentivesClaimingLogicFactory factory);

    function setUp() public {
        incentivesModule = VaultIncentivesModule(Clones.clone(address(new VaultIncentivesModule())));
        incentivesModule.__VaultIncentivesModule_init(
            ISiloVault(_vault),
            address(0),
            new IIncentivesClaimingLogic[](0),
            new IERC4626[](0),
            new IIncentivesClaimingLogicFactory[](0)
        );

        vm.mockCall(
            address(incentivesModule.vault()),
            abi.encodeWithSelector(ISiloVaultBase.timelock.selector),
            abi.encode(_timelock)
        );

        vm.mockCall(
            address(incentivesModule.vault()),
            abi.encodeWithSelector(ISiloVaultBase.guardian.selector),
            abi.encode(_guardian)
        );

        vm.mockCall(
            address(incentivesModule.vault()),
            abi.encodeWithSelector(ISiloVaultBase.curator.selector),
            abi.encode(_curator)
        );

        vm.mockCall(
            address(incentivesModule.vault()),
            abi.encodeWithSelector(Ownable.owner.selector),
            abi.encode(_deployer)
        );
    }

    /*
    FOUNDRY_PROFILE=vaults_tests forge test --mt test_IncentivesModule_new -vvv
    */
    function test_IncentivesModule_new() public {
        VaultIncentivesModule module = new VaultIncentivesModule();
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        module.__VaultIncentivesModule_init(
            ISiloVault(_vault),
            address(0),
            new IIncentivesClaimingLogic[](0),
            new IERC4626[](0),
            new IIncentivesClaimingLogicFactory[](0)
        );
    }

    /*
    FOUNDRY_PROFILE=vaults_tests forge test --mt test_IncentivesModule_init -vvv
    */
    function test_IncentivesModule_init() public {
        address module = Clones.clone(address(new VaultIncentivesModule()));

        vm.expectRevert(); // not initialized, vault is not set
        VaultIncentivesModule(module).owner();

        VaultIncentivesModule(module).__VaultIncentivesModule_init(
            ISiloVault(_vault),
            address(0),
            new IIncentivesClaimingLogic[](0),
            new IERC4626[](0),
            new IIncentivesClaimingLogicFactory[](0)
        );

        assertEq(VaultIncentivesModule(module).owner(), _deployer, "valid owner");
        assertEq(address(VaultIncentivesModule(module).vault()), _vault, "valid vault");
    }

    /*
    FOUNDRY_PROFILE=vaults_tests forge test --mt test_IncentivesModule_initOnce -vvv
    */
    function test_IncentivesModule_initOnce() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        incentivesModule.__VaultIncentivesModule_init(
            ISiloVault(_vault),
            address(0),
            new IIncentivesClaimingLogic[](0),
            new IERC4626[](0),
            new IIncentivesClaimingLogicFactory[](0)
        );
    }

    /*
    forge test --mt test_submitAcceptIncentivesClaimingLogicAndGetter -vvv
    */
    function test_submitAcceptIncentivesClaimingLogicAndGetter() public {
        vm.prank(_deployer);
        incentivesModule.submitIncentivesClaimingLogic(_market1, _logic1);

        vm.prank(_deployer);
        incentivesModule.submitIncentivesClaimingLogic(_market2, _logic2);

        vm.warp(block.timestamp + _timelock + 1);

        vm.expectEmit(true, true, true, true);
        emit IncentivesClaimingLogicAdded(_market1, _logic1);

        vm.prank(_guardian);
        incentivesModule.acceptIncentivesClaimingLogic(_market1, _logic1);

        vm.expectEmit(true, true, true, true);
        emit IncentivesClaimingLogicAdded(_market2, _logic2);

        vm.prank(_guardian);
        incentivesModule.acceptIncentivesClaimingLogic(_market2, _logic2);

        address[] memory logics = incentivesModule.getAllIncentivesClaimingLogics();
        assertEq(logics.length, 2);
        assertEq(logics[0], address(_logic1));
        assertEq(logics[1], address(_logic2));

        address[] memory expectedLogics1 = new address[](1);
        expectedLogics1[0] = address(_logic1);

        address[] memory expectedLogics2 = new address[](1);
        expectedLogics2[0] = address(_logic2);

        assertEq(incentivesModule.getMarketIncentivesClaimingLogics(_market1), expectedLogics1);
        assertEq(incentivesModule.getMarketIncentivesClaimingLogics(_market2), expectedLogics2);

        address[] memory expectedMarkets = new address[](2);
        expectedMarkets[0] = address(_market1);
        expectedMarkets[1] = address(_market2);

        assertEq(incentivesModule.getConfiguredMarkets(), expectedMarkets);
    }

    /*
    forge test --mt test_submitIncentivesClaimingLogic_success -vvv
    */
    function test_submitIncentivesClaimingLogic_success() public {
        vm.expectEmit(true, true, true, true);
        emit SubmitIncentivesClaimingLogic(_market1, _logic1);

        vm.prank(_deployer);
        incentivesModule.submitIncentivesClaimingLogic(_market1, _logic1);

        assertEq(incentivesModule.pendingClaimingLogics(_market1, _logic1), block.timestamp + _timelock, "pending logic");
    }

    /*
    forge test --mt test_submitIncentivesClaimingLogic_alreadyAdded -vvv
    */
    function test_submitIncentivesClaimingLogic_alreadyAdded() public {
        vm.prank(_deployer);
        incentivesModule.submitIncentivesClaimingLogic(_market1, _logic1);

        vm.warp(block.timestamp + _timelock + 1);

        vm.prank(_guardian);
        incentivesModule.acceptIncentivesClaimingLogic(_market1, _logic1);

        vm.expectRevert(IVaultIncentivesModule.LogicAlreadyAdded.selector);
        vm.prank(_deployer);
        incentivesModule.submitIncentivesClaimingLogic(_market1, _logic1);
    }

    /*
    forge test --mt test_submitIncentivesClaimingLogic_alreadyPending -vvv
    */
    function test_submitIncentivesClaimingLogic_alreadyPending() public {
        vm.prank(_deployer);
        incentivesModule.submitIncentivesClaimingLogic(_market1, _logic1);

        vm.expectRevert(IVaultIncentivesModule.LogicAlreadyPending.selector);
        vm.prank(_deployer);
        incentivesModule.submitIncentivesClaimingLogic(_market1, _logic1);
    }

    /*
    forge test --mt test_submitIncentivesClaimingLogic_zeroAddress -vvv
    */
    function test_submitIncentivesClaimingLogic_zeroAddress() public {
        vm.expectRevert(IVaultIncentivesModule.AddressZero.selector);
        vm.prank(_deployer);
        incentivesModule.submitIncentivesClaimingLogic(_market1, IIncentivesClaimingLogic(address(0)));
    }

    /*
    forge test --mt test_submitIncentivesClaimingLogic_OnlyOwner -vvv
    */
    function test_submitIncentivesClaimingLogic_OnlyOwner() public {
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotOwner.selector));
        incentivesModule.submitIncentivesClaimingLogic(_market1, _logic1);
    }

    /*
    forge test --mt test_removeIncentivesClaimingLogic -vvv
    */
    function test_removeIncentivesClaimingLogic() public {
        vm.prank(_deployer);
        incentivesModule.submitIncentivesClaimingLogic(_market1, _logic1);

        vm.warp(block.timestamp + _timelock + 1);

        vm.prank(_guardian);
        incentivesModule.acceptIncentivesClaimingLogic(_market1, _logic1);

        address[] memory logics = incentivesModule.getAllIncentivesClaimingLogics();
        assertEq(logics.length, 1);

        address[] memory expectedMarkets = new address[](1);
        expectedMarkets[0] = address(_market1);

        assertEq(incentivesModule.getConfiguredMarkets(), expectedMarkets);

        vm.expectEmit(true, true, true, true);
        emit IncentivesClaimingLogicRemoved(_market1, _logic1);

        vm.prank(_deployer);
        incentivesModule.removeIncentivesClaimingLogic(_market1, _logic1);

        logics = incentivesModule.getAllIncentivesClaimingLogics();
        assertEq(logics.length, 0);

        expectedMarkets = new address[](0);
        assertEq(incentivesModule.getConfiguredMarkets(), expectedMarkets);
    }

    /*
    forge test --mt test_removeIncentivesClaimingLogic_notAdded -vvv
    */
    function test_removeIncentivesClaimingLogic_notAdded() public {
        vm.expectRevert(IVaultIncentivesModule.LogicNotFound.selector);
        vm.prank(_deployer);
        incentivesModule.removeIncentivesClaimingLogic(_market1, _logic1);
    }

    /*
    forge test --mt test_removeIncentivesClaimingLogic_onlyOwner -vvv
    */
    function test_removeIncentivesClaimingLogic_onlyOwner() public {
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotOwner.selector));
        incentivesModule.removeIncentivesClaimingLogic(_market1, _logic1);
    }

    /*
    forge test --mt test_revokePendingClaimingLogic_onlyGuardian -vvv
    */
    function test_revokePendingClaimingLogic_onlyGuardian() public {
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotGuardianRole.selector));
        incentivesModule.revokePendingClaimingLogic(_market1, _logic1);
    }

    /*
    forge test --mt test_revokePendingClaimingLogic_success -vvv
    */
    function test_revokePendingClaimingLogic_success() public {
        vm.prank(_deployer);
        incentivesModule.submitIncentivesClaimingLogic(_market1, _logic1);

        vm.expectEmit(true, true, true, true);
        emit RevokePendingClaimingLogic(_market1, _logic1);

        vm.prank(_guardian);
        incentivesModule.revokePendingClaimingLogic(_market1, _logic1);

        assertEq(incentivesModule.pendingClaimingLogics(_market1, _logic1), 0, "failed to revoke pending logic");
    }

    /*
    forge test --mt test_addNotificationReceiverAndGetter -vvv
    */
    function test_addNotificationReceiverAndGetter() public {
        vm.expectEmit(true, true, true, true);
        emit NotificationReceiverAdded(_solution1);

        vm.prank(_deployer);
        incentivesModule.addNotificationReceiver(INotificationReceiver(_solution1));

        vm.expectEmit(true, true, true, true);
        emit NotificationReceiverAdded(_solution2);

        vm.prank(_deployer);
        incentivesModule.addNotificationReceiver(INotificationReceiver(_solution2));

        address[] memory solutions = incentivesModule.getNotificationReceivers();

        assertEq(solutions.length, 2);
        assertEq(solutions[0], _solution1);
        assertEq(solutions[1], _solution2);
    }

    /*
    forge test --mt test_addNotificationReceiver_alreadyAdded -vvv
    */
    function test_addNotificationReceiver_alreadyAdded() public {
        vm.prank(_deployer);
        incentivesModule.addNotificationReceiver(INotificationReceiver(_solution1));

        vm.expectRevert(IVaultIncentivesModule.NotificationReceiverAlreadyAdded.selector);
        vm.prank(_deployer);
        incentivesModule.addNotificationReceiver(INotificationReceiver(_solution1));
    }

    /*
    forge test --mt test_addNotificationReceiver_zeroAddress -vvv
    */
    function test_addNotificationReceiver_zeroAddress() public {
        vm.expectRevert(IVaultIncentivesModule.AddressZero.selector);
        vm.prank(_deployer);
        incentivesModule.addNotificationReceiver(INotificationReceiver(address(0)));
    }

    /*
    forge test --mt test_addNotificationReceiver_onlyOwner -vvv
    */
    function test_addNotificationReceiver_onlyOwner() public {
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotOwner.selector));
        incentivesModule.addNotificationReceiver(INotificationReceiver(_solution1));
    }

    /*
    forge test --mt test_removeNotificationReceiver -vvv
    */
    function test_removeNotificationReceiver() public {
        vm.prank(_deployer);
        incentivesModule.addNotificationReceiver(INotificationReceiver(_solution1));

        address[] memory solutions = incentivesModule.getNotificationReceivers();
        assertEq(solutions.length, 1);

        vm.expectEmit(true, true, true, true);
        emit NotificationReceiverRemoved(_solution1);

        vm.prank(_deployer);
        incentivesModule.removeNotificationReceiver(INotificationReceiver(_solution1), _ALL_PROGRAMS_STOPPED);

        solutions = incentivesModule.getNotificationReceivers();
        assertEq(solutions.length, 0);
    }

    /*
    forge test --mt test_removeNotificationReceiver_allProgramsNotStopped -vvv
    */
    function test_removeNotificationReceiver_allProgramsNotStopped() public {
        vm.expectRevert(IVaultIncentivesModule.AllProgramsNotStopped.selector);
        vm.prank(_deployer);
        incentivesModule.removeNotificationReceiver(INotificationReceiver(_solution1), !_ALL_PROGRAMS_STOPPED);
    }

    /*
    forge test --mt test_removeNotificationReceiver_notAdded -vvv
    */
    function test_removeNotificationReceiver_notAdded() public {
        vm.expectRevert(IVaultIncentivesModule.NotificationReceiverNotFound.selector);
        vm.prank(_deployer);
        incentivesModule.removeNotificationReceiver(INotificationReceiver(_solution1), _ALL_PROGRAMS_STOPPED);
    }

    /*
    forge test --mt test_removeNotificationReceiver_onlyOwner -vvv
    */
    function test_removeNotificationReceiver_onlyOwner() public {
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotOwner.selector));
        incentivesModule.removeNotificationReceiver(INotificationReceiver(_solution1), _ALL_PROGRAMS_STOPPED);
    }

    /*
    forge test --mt test_vaultIncentivesModule_ownershipTransfer -vvv
    */
    function test_vaultIncentivesModule_ownershipTransfer() public {
        Ownable2Step ownableModule = Ownable2Step(address(incentivesModule));

        assertEq(ownableModule.owner(), _deployer);

        address newOwner = makeAddr("NewOwner");

        vm.mockCall(
            address(incentivesModule.vault()),
            abi.encodeWithSelector(Ownable.owner.selector),
            abi.encode(newOwner)
        );

        assertEq(ownableModule.owner(), newOwner);
    }

    /*
    FOUNDRY_PROFILE=vaults_tests forge test --mt test_submitTrustedFactory_onlyOwner -vv
    */
    function test_submitTrustedFactory_onlyOwner() public {
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotOwner.selector));
        incentivesModule.submitTrustedFactory(_trustedFactory);

        vm.prank(_guardian);
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotOwner.selector));
        incentivesModule.submitTrustedFactory(_trustedFactory);
    }

    /*
    FOUNDRY_PROFILE=vaults_tests forge test --mt test_submitTrustedFactory_addressZero -vvv
    */
    function test_submitTrustedFactory_addressZero() public {
        vm.expectRevert(IVaultIncentivesModule.AddressZero.selector);
        vm.prank(_deployer);
        incentivesModule.submitTrustedFactory(IIncentivesClaimingLogicFactory(address(0)));
    }

    /*
    FOUNDRY_PROFILE=vaults_tests forge test --mt test_submitTrustedFactory_success -vvv
    */
    function test_submitTrustedFactory_success() public {
        vm.expectEmit(true, true, true, true);
        emit TrustedFactorySubmitted(_trustedFactory);

        vm.prank(_deployer);
        incentivesModule.submitTrustedFactory(_trustedFactory);
    }

    /*
    FOUNDRY_PROFILE=vaults_tests forge test --mt test_submitTrustedFactory_alreadyPending -vvv
    */
    function test_submitTrustedFactory_alreadyPending() public {
        vm.prank(_deployer);
        incentivesModule.submitTrustedFactory(_trustedFactory);

        vm.prank(_deployer);
        vm.expectRevert(IVaultIncentivesModule.FactoryAlreadyPending.selector);
        incentivesModule.submitTrustedFactory(_trustedFactory);
    }

    /*
    FOUNDRY_PROFILE=vaults_tests forge test --mt test_revokePendingTrustedFactory_onlyGuardian -vvv
    */
    function test_revokePendingTrustedFactory_onlyGuardian() public {
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotGuardianRole.selector));
        incentivesModule.revokePendingTrustedFactory(_trustedFactory);
    }

    /*
    FOUNDRY_PROFILE=vaults_tests forge test --mt test_revokePendingTrustedFactory_success -vvv
    */
    function test_revokePendingTrustedFactory_success() public {
        vm.prank(_deployer);
        incentivesModule.submitTrustedFactory(_trustedFactory);

        vm.expectEmit(true, true, true, true);
        emit TrustedFactoryRevoked(_trustedFactory);

        vm.prank(_guardian);
        incentivesModule.revokePendingTrustedFactory(_trustedFactory);
    }

    /*
    FOUNDRY_PROFILE=vaults_tests forge test --mt test_acceptTrustedFactory_cantAcceptFactory -vvv
    */
    function test_acceptTrustedFactory_cantAcceptFactory() public {
        vm.expectRevert(IVaultIncentivesModule.CantAcceptFactory.selector);
        incentivesModule.acceptTrustedFactory(_trustedFactory);

        vm.prank(_deployer);
        incentivesModule.submitTrustedFactory(_trustedFactory);

        vm.warp(block.timestamp + _timelock - 1);

        vm.expectRevert(IVaultIncentivesModule.CantAcceptFactory.selector);
        incentivesModule.acceptTrustedFactory(_trustedFactory);
    }

    /*
    FOUNDRY_PROFILE=vaults_tests forge test --mt test_acceptTrustedFactory_success -vvv
    */
    function test_acceptTrustedFactory_success() public {
        vm.prank(_deployer);
        incentivesModule.submitTrustedFactory(_trustedFactory);

        vm.warp(block.timestamp + _timelock + 1);

        vm.expectEmit(true, true, true, true);
        emit TrustedFactoryAdded(_trustedFactory);

        vm.prank(_guardian);
        incentivesModule.acceptTrustedFactory(_trustedFactory);
    }

    /*
    FOUNDRY_PROFILE=vaults_tests forge test --mt test_removeTrustedFactory_onlyOwner -vvv
    */
    function test_removeTrustedFactory_onlyOwner() public {
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotOwner.selector));
        incentivesModule.removeTrustedFactory(_trustedFactory);

        vm.prank(_guardian);
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotOwner.selector));
        incentivesModule.removeTrustedFactory(_trustedFactory);
    }

    /*
    FOUNDRY_PROFILE=vaults_tests forge test --mt test_removeTrustedFactory_success -vvv
    */
    function test_removeTrustedFactory_success() public {
        vm.prank(_deployer);
        incentivesModule.submitTrustedFactory(_trustedFactory);

        vm.warp(block.timestamp + _timelock + 1);

        incentivesModule.acceptTrustedFactory(_trustedFactory);

        vm.expectEmit(true, true, true, true);
        emit TrustedFactoryRemoved(_trustedFactory);

        vm.prank(_deployer);
        incentivesModule.removeTrustedFactory(_trustedFactory);
    }

    /*
    FOUNDRY_PROFILE=vaults_tests forge test --mt test_trustedFactories_getters -vvv
    */
    function test_trustedFactories_getters() public {
        vm.prank(_deployer);
        incentivesModule.submitTrustedFactory(_trustedFactory);

        vm.warp(block.timestamp + _timelock + 1);

        incentivesModule.acceptTrustedFactory(_trustedFactory);

        address[] memory factories = incentivesModule.getTrustedFactories();
        assertEq(factories.length, 1);
        assertEq(factories[0], address(_trustedFactory));

        assertTrue(incentivesModule.isTrustedFactory(_trustedFactory));
    }

    /*
    FOUNDRY_PROFILE=vaults_tests forge test --mt test_submitIncentivesClaimingLogic_logicCreatedInTrustedFactory -vvv
    */
    function test_submitIncentivesClaimingLogic_logicCreatedInTrustedFactory() public {
        vm.prank(_deployer);
        incentivesModule.submitTrustedFactory(_trustedFactory);

        vm.warp(block.timestamp + _timelock + 1);

        incentivesModule.acceptTrustedFactory(_trustedFactory);

        vm.mockCall(
            address(_trustedFactory),
            abi.encodeWithSelector(IIncentivesClaimingLogicFactory.createdInFactory.selector, address(_logic1)),
            abi.encode(true)
        );

        vm.prank(_deployer);
        incentivesModule.submitIncentivesClaimingLogic(_market1, _logic1);
        incentivesModule.acceptIncentivesClaimingLogic(_market1, _logic1);

        vm.mockCall(
            address(_trustedFactory),
            abi.encodeWithSelector(IIncentivesClaimingLogicFactory.createdInFactory.selector, address(_logic2)),
            abi.encode(true)
        );

        vm.prank(_curator);
        incentivesModule.submitIncentivesClaimingLogic(_market2, _logic2);
        incentivesModule.acceptIncentivesClaimingLogic(_market2, _logic2);

        address[] memory claimingLogics = incentivesModule.getAllIncentivesClaimingLogics();
        assertEq(claimingLogics.length, 2, "failed to add claiming logics");
        assertEq(claimingLogics[0], address(_logic1), "failed to add claiming logic 1");
        assertEq(claimingLogics[1], address(_logic2), "failed to add claiming logic 2");
    }

    /*
    FOUNDRY_PROFILE=vaults_tests forge test --mt test_submitIncentivesClaimingLogic_onlyCurator -vvv
    */
    function test_submitIncentivesClaimingLogic_onlyCurator() public {
         vm.prank(_deployer);
        incentivesModule.submitTrustedFactory(_trustedFactory);

        vm.warp(block.timestamp + _timelock + 1);

        incentivesModule.acceptTrustedFactory(_trustedFactory);

        vm.mockCall(
            address(_trustedFactory),
            abi.encodeWithSelector(IIncentivesClaimingLogicFactory.createdInFactory.selector, address(_logic1)),
            abi.encode(true)
        );

        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.NotCuratorRole.selector));
        incentivesModule.submitIncentivesClaimingLogic(_market1, _logic1);
    }
}
