// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";

import {IIncentivesClaimingLogic} from "silo-vaults/contracts/interfaces/IIncentivesClaimingLogic.sol";
import {INotificationReceiver} from "silo-vaults/contracts/interfaces/INotificationReceiver.sol";
import {VaultIncentivesModule} from "silo-vaults/contracts/incentives/VaultIncentivesModule.sol";
import {VaultIncentivesModuleDeploy} from "silo-vaults/deploy/VaultIncentivesModuleDeploy.s.sol";
import {IVaultIncentivesModule} from "silo-vaults/contracts/interfaces/IVaultIncentivesModule.sol";

/*
forge test --mc VaultIncentivesModuleTest -vv
*/
contract VaultIncentivesModuleTest is Test {
    VaultIncentivesModule public incentivesModule;

    address internal _solution1 = makeAddr("Solution1");
    address internal _solution2 = makeAddr("Solution2");

    address internal _logic1 = makeAddr("Logic1");
    address internal _logic2 = makeAddr("Logic2");

    address internal _market1 = makeAddr("Market1");
    address internal _market2 = makeAddr("Market2");

    address internal _deployer;

    event IncentivesClaimingLogicAdded(address indexed market, address logic);
    event IncentivesClaimingLogicRemoved(address indexed market, address logic);
    event NotificationReceiverAdded(address notificationReceiver);
    event NotificationReceiverRemoved(address notificationReceiver);

    function setUp() public {
        VaultIncentivesModuleDeploy deployer = new VaultIncentivesModuleDeploy();
        deployer.disableDeploymentsSync();

        incentivesModule = deployer.run();

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        _deployer = vm.addr(deployerPrivateKey);
    }

    /*
    forge test --mt test_addIncentivesClaimingLogicAndGetter -vvv
    */
    function test_addIncentivesClaimingLogicAndGetter() public {
        vm.expectEmit(true, true, true, true);
        emit IncentivesClaimingLogicAdded(_market1, _logic1);

        vm.prank(_deployer);
        incentivesModule.addIncentivesClaimingLogic(_market1, IIncentivesClaimingLogic(_logic1));

        vm.expectEmit(true, true, true, true);
        emit IncentivesClaimingLogicAdded(_market2, _logic2);

        vm.prank(_deployer);
        incentivesModule.addIncentivesClaimingLogic(_market2, IIncentivesClaimingLogic(_logic2));

        address[] memory logics = incentivesModule.getAllIncentivesClaimingLogics();
        assertEq(logics.length, 2);
        assertEq(logics[0], _logic1);
        assertEq(logics[1], _logic2);

        address[] memory expectedLogics1 = new address[](1);
        expectedLogics1[0] = _logic1;

        address[] memory expectedLogics2 = new address[](1);
        expectedLogics2[0] = _logic2;

        assertEq(incentivesModule.getMarketIncentivesClaimingLogics(_market1), expectedLogics1);
        assertEq(incentivesModule.getMarketIncentivesClaimingLogics(_market2), expectedLogics2);

        address[] memory expectedMarkets = new address[](2);
        expectedMarkets[0] = _market1;
        expectedMarkets[1] = _market2;

        assertEq(incentivesModule.getConfiguredMarkets(), expectedMarkets);
    }

    /*
    forge test --mt test_addIncentivesClaimingLogic_alreadyAdded -vvv
    */
    function test_addIncentivesClaimingLogic_alreadyAdded() public {
        vm.prank(_deployer);
        incentivesModule.addIncentivesClaimingLogic(_market1, IIncentivesClaimingLogic(_logic1));

        vm.expectRevert(IVaultIncentivesModule.LogicAlreadyAdded.selector);
        vm.prank(_deployer);
        incentivesModule.addIncentivesClaimingLogic(_market1, IIncentivesClaimingLogic(_logic1));
    }

    /*
    forge test --mt test_addIncentivesClaimingLogic_zeroAddress -vvv
    */
    function test_addIncentivesClaimingLogic_zeroAddress() public {
        vm.expectRevert(IVaultIncentivesModule.AddressZero.selector);
        vm.prank(_deployer);
        incentivesModule.addIncentivesClaimingLogic(_market1, IIncentivesClaimingLogic(address(0)));
    }

    /*
    forge test --mt test_addIncentivesClaimingLogic_onlyOwner -vvv
    */
    function test_addIncentivesClaimingLogic_onlyOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        incentivesModule.addIncentivesClaimingLogic(_market1, IIncentivesClaimingLogic(_logic1));
    }

    /*
    forge test --mt test_removeIncentivesClaimingLogic -vvv
    */
    function test_removeIncentivesClaimingLogic() public {
        vm.prank(_deployer);
        incentivesModule.addIncentivesClaimingLogic(_market1, IIncentivesClaimingLogic(_logic1));

        address[] memory logics = incentivesModule.getAllIncentivesClaimingLogics();
        assertEq(logics.length, 1);

        address[] memory expectedMarkets = new address[](1);
        expectedMarkets[0] = _market1;

        assertEq(incentivesModule.getConfiguredMarkets(), expectedMarkets);

        vm.expectEmit(true, true, true, true);
        emit IncentivesClaimingLogicRemoved(_market1, _logic1);

        vm.prank(_deployer);
        incentivesModule.removeIncentivesClaimingLogic(_market1, IIncentivesClaimingLogic(_logic1));

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
        incentivesModule.removeIncentivesClaimingLogic(_market1, IIncentivesClaimingLogic(_logic1));
    }

    /*
    forge test --mt test_removeIncentivesClaimingLogic_onlyOwner -vvv
    */
    function test_removeIncentivesClaimingLogic_onlyOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        incentivesModule.removeIncentivesClaimingLogic(_market1, IIncentivesClaimingLogic(_logic1));
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
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
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
        incentivesModule.removeNotificationReceiver(INotificationReceiver(_solution1));

        solutions = incentivesModule.getNotificationReceivers();
        assertEq(solutions.length, 0);
    }

    /*
    forge test --mt test_removeNotificationReceiver_notAdded -vvv
    */
    function test_removeNotificationReceiver_notAdded() public {
        vm.expectRevert(IVaultIncentivesModule.NotificationReceiverNotFound.selector);
        vm.prank(_deployer);
        incentivesModule.removeNotificationReceiver(INotificationReceiver(_solution1));
    }

    /*
    forge test --mt test_removeNotificationReceiver_onlyOwner -vvv
    */
    function test_removeNotificationReceiver_onlyOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        incentivesModule.removeNotificationReceiver(INotificationReceiver(_solution1));
    }

    /*
    forge test --mt test_vaultIncentivesModule_ownershipTransfer -vvv
    */
    function test_vaultIncentivesModule_ownershipTransfer() public {
        address newOwner = makeAddr("NewOwner");

        Ownable2Step module = Ownable2Step(address(incentivesModule));

        vm.prank(_deployer);
        module.transferOwnership(newOwner);

        assertEq(module.pendingOwner(), newOwner);

        vm.prank(newOwner);
        module.acceptOwnership();

        assertEq(module.owner(), newOwner);
    }
}
