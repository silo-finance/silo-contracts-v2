// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "openzeppelin5/access/Ownable.sol";

import {WhitelistComplianceResolver} from "silo-core/contracts/hooks/compliance/resolvers/WhitelistComplianceResolver.sol";
import {IWhitelistComplianceResolver} from "silo-core/contracts/interfaces/compliance/IWhitelistComplianceResolver.sol";
import {WhitelistComplianceResolverDeploy} from "silo-core/deploy/WhitelistComplianceResolverDeploy.s.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";

// FOUNDRY_PROFILE=core_test forge test --mc WhitelistComplianceResolverTest -vvv
contract WhitelistComplianceResolverTest is Test {
    IWhitelistComplianceResolver internal _resolver;
    
    address internal _owner;
    address internal _user1 = makeAddr("user1");
    address internal _user2 = makeAddr("user2");
    address internal _user3 = makeAddr("user3");
    
    // Use actions from Hook.sol
    uint256 internal constant DEPOSIT_ACTION = Hook.DEPOSIT;
    uint256 internal constant BORROW_ACTION = Hook.BORROW;
    uint256 internal constant WITHDRAW_ACTION = Hook.WITHDRAW;
    uint256 internal constant REPAY_ACTION = Hook.REPAY;

    function setUp() public {
        uint256 privateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        _owner = vm.addr(privateKey);

        // Deploy the resolver using the deployment script
        WhitelistComplianceResolverDeploy deployer = new WhitelistComplianceResolverDeploy();
        deployer.disableDeploymentsSync();
        _resolver = deployer.run();
    }
    
    // FOUNDRY_PROFILE=core_test forge test --mt testAddToWhitelistDeposit -vvv
    function testAddToWhitelistDeposit() public {
        // Add user1 to the whitelist for DEPOSIT_ACTION
        uint256[] memory actions = new uint256[](1);
        actions[0] = DEPOSIT_ACTION;
        
        address[] memory addresses = new address[](1);
        addresses[0] = _user1;

        vm.prank(_owner);
        _resolver.addToWhitelist(actions, addresses);
        
        // Verify user1 is in the whitelist for DEPOSIT_ACTION
        assertTrue(_resolver.isInWhitelist(DEPOSIT_ACTION, _user1));
        assertFalse(_resolver.isInWhitelist(BORROW_ACTION, _user1));
        
        // Get whitelist for DEPOSIT_ACTION and verify it contains user1
        address[] memory whitelist = _resolver.getWhitelist(DEPOSIT_ACTION);
        assertEq(whitelist.length, 1);
        assertEq(whitelist[0], _user1);
    }
    
    // FOUNDRY_PROFILE=core_test forge test --mt testAddMultipleActionsToWhitelist -vvv
    function testAddMultipleActionsToWhitelist() public {
        // Add multiple users to multiple actions
        uint256[] memory actions = new uint256[](3);
        actions[0] = DEPOSIT_ACTION;
        actions[1] = BORROW_ACTION;
        actions[2] = WITHDRAW_ACTION;

        address[] memory addresses = new address[](3);
        addresses[0] = _user1;
        addresses[1] = _user2;
        addresses[2] = _user3;

        vm.prank(_owner);
        _resolver.addToWhitelist(actions, addresses);

        // Verify users are in the whitelist for their respective actions
        assertTrue(_resolver.isInWhitelist(DEPOSIT_ACTION, _user1));
        assertTrue(_resolver.isInWhitelist(BORROW_ACTION, _user2));
        assertTrue(_resolver.isInWhitelist(WITHDRAW_ACTION, _user3));

        // Get whitelist for each action and verify
        address[] memory depositWhitelist = _resolver.getWhitelist(DEPOSIT_ACTION);
        assertEq(depositWhitelist.length, 1);
        assertEq(depositWhitelist[0], _user1);

        address[] memory borrowWhitelist = _resolver.getWhitelist(BORROW_ACTION);
        assertEq(borrowWhitelist.length, 1);
        assertEq(borrowWhitelist[0], _user2);

        address[] memory withdrawWhitelist = _resolver.getWhitelist(WITHDRAW_ACTION);
        assertEq(withdrawWhitelist.length, 1);
        assertEq(withdrawWhitelist[0], _user3);
    }
    
    // FOUNDRY_PROFILE=core_test forge test --mt testRemoveFromWhitelist -vvv
    function testRemoveFromWhitelist() public {
        // Add users to whitelist for DEPOSIT_ACTION
        uint256[] memory actions = new uint256[](2);
        actions[0] = DEPOSIT_ACTION;
        actions[1] = DEPOSIT_ACTION;
        
        address[] memory addresses = new address[](2);
        addresses[0] = _user1;
        addresses[1] = _user2;

        vm.prank(_owner);
        _resolver.addToWhitelist(actions, addresses);

        // Verify users are in the whitelist
        assertTrue(_resolver.isInWhitelist(DEPOSIT_ACTION, _user1));
        assertTrue(_resolver.isInWhitelist(DEPOSIT_ACTION, _user2));

        // Remove user1 from whitelist
        uint256[] memory removeActions = new uint256[](1);
        removeActions[0] = DEPOSIT_ACTION;
        
        address[] memory removeAddresses = new address[](1);
        removeAddresses[0] = _user1;

        vm.prank(_owner);
        _resolver.removeFromWhitelist(removeActions, removeAddresses);
        
        // Verify user1 is no longer in the whitelist but user2 still is
        assertFalse(_resolver.isInWhitelist(DEPOSIT_ACTION, _user1));
        assertTrue(_resolver.isInWhitelist(DEPOSIT_ACTION, _user2));
        
        // Get whitelist for DEPOSIT_ACTION and verify it contains only user2
        address[] memory whitelist = _resolver.getWhitelist(DEPOSIT_ACTION);
        assertEq(whitelist.length, 1);
        assertEq(whitelist[0], _user2);
    }
    
    // FOUNDRY_PROFILE=core_test forge test --mt testRemoveMultipleFromWhitelist -vvv
    function testRemoveMultipleFromWhitelist() public {
        // Add users to whitelist for different actions
        uint256[] memory actions = new uint256[](3);
        actions[0] = DEPOSIT_ACTION;
        actions[1] = BORROW_ACTION;
        actions[2] = WITHDRAW_ACTION;

        address[] memory addresses = new address[](3);
        addresses[0] = _user1;
        addresses[1] = _user2;
        addresses[2] = _user3;

        vm.prank(_owner);
        _resolver.addToWhitelist(actions, addresses);

        // Remove users from whitelist
        uint256[] memory removeActions = new uint256[](2);
        removeActions[0] = DEPOSIT_ACTION;
        removeActions[1] = BORROW_ACTION;
        
        address[] memory removeAddresses = new address[](2);
        removeAddresses[0] = _user1;
        removeAddresses[1] = _user2;

        vm.prank(_owner);
        _resolver.removeFromWhitelist(removeActions, removeAddresses);
        
        // Verify users are no longer in the whitelist
        assertFalse(_resolver.isInWhitelist(DEPOSIT_ACTION, _user1));
        assertFalse(_resolver.isInWhitelist(BORROW_ACTION, _user2));
        assertTrue(_resolver.isInWhitelist(WITHDRAW_ACTION, _user3));
    }
    
    // FOUNDRY_PROFILE=core_test forge test --mt testAddEmptyAddress -vvv
    function testAddEmptyAddress() public {
        uint256[] memory actions = new uint256[](1);
        actions[0] = DEPOSIT_ACTION;

        address[] memory addresses = new address[](1);
        addresses[0] = address(0);

        vm.prank(_owner);
        vm.expectRevert(IWhitelistComplianceResolver.EmptyAddress.selector);
        _resolver.addToWhitelist(actions, addresses);
    }
    
    // FOUNDRY_PROFILE=core_test forge test --mt testAddAlreadyWhitelisted -vvv
    function testAddAlreadyWhitelisted() public {
        // Add user1 to whitelist for DEPOSIT_ACTION
        uint256[] memory actions = new uint256[](1);
        actions[0] = DEPOSIT_ACTION;
        
        address[] memory addresses = new address[](1);
        addresses[0] = _user1;

        vm.prank(_owner);
        _resolver.addToWhitelist(actions, addresses);
        
        // Try to add user1 to the same action again
        vm.prank(_owner);
        vm.expectRevert(IWhitelistComplianceResolver.AddressAlreadyWhitelisted.selector);
        _resolver.addToWhitelist(actions, addresses);
    }
    
    // FOUNDRY_PROFILE=core_test forge test --mt testRemoveNotWhitelisted -vvv
    function testRemoveNotWhitelisted() public {
        uint256[] memory actions = new uint256[](1);
        actions[0] = DEPOSIT_ACTION;
        
        address[] memory addresses = new address[](1);
        addresses[0] = _user1;

        vm.prank(_owner);
        vm.expectRevert(IWhitelistComplianceResolver.AddressNotWhitelisted.selector);
        _resolver.removeFromWhitelist(actions, addresses);
    }
    
    // FOUNDRY_PROFILE=core_test forge test --mt testEmptyArrays -vvv
    function testEmptyArrays() public {
        uint256[] memory emptyActions = new uint256[](0);
        address[] memory addresses = new address[](1);
        addresses[0] = _user1;

        vm.prank(_owner);
        vm.expectRevert(IWhitelistComplianceResolver.EmptyArrayInput.selector);
        _resolver.addToWhitelist(emptyActions, addresses);
        
        uint256[] memory actions = new uint256[](1);
        actions[0] = DEPOSIT_ACTION;
        address[] memory emptyAddresses = new address[](0);

        vm.prank(_owner);
        vm.expectRevert(IWhitelistComplianceResolver.EmptyArrayInput.selector);
        _resolver.addToWhitelist(actions, emptyAddresses);

        vm.prank(_owner);
        vm.expectRevert(IWhitelistComplianceResolver.EmptyArrayInput.selector);
        _resolver.removeFromWhitelist(emptyActions, addresses);

        vm.prank(_owner);
        vm.expectRevert(IWhitelistComplianceResolver.EmptyArrayInput.selector);
        _resolver.removeFromWhitelist(actions, emptyAddresses);
    }
    
    // FOUNDRY_PROFILE=core_test forge test --mt testArrayLengthMismatch -vvv
    function testArrayLengthMismatch() public {
        uint256[] memory actions = new uint256[](2);
        actions[0] = DEPOSIT_ACTION;
        actions[1] = BORROW_ACTION;
        
        address[] memory addresses = new address[](1);
        addresses[0] = _user1;

        vm.prank(_owner);
        vm.expectRevert(IWhitelistComplianceResolver.InvalidArrayLength.selector);
        _resolver.addToWhitelist(actions, addresses);

        vm.prank(_owner);
        vm.expectRevert(IWhitelistComplianceResolver.InvalidArrayLength.selector);
        _resolver.removeFromWhitelist(actions, addresses);
    }
    
    // FOUNDRY_PROFILE=core_test forge test --mt testOnlyOwnerCanAddToWhitelist -vvv
    function testOnlyOwnerCanAddToWhitelist() public {
        uint256[] memory actions = new uint256[](1);
        actions[0] = DEPOSIT_ACTION;
        
        address[] memory addresses = new address[](1);
        addresses[0] = _user1;
        
        vm.prank(_user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _user1));
        _resolver.addToWhitelist(actions, addresses);
    }
    
    // FOUNDRY_PROFILE=core_test forge test --mt testOnlyOwnerCanRemoveFromWhitelist -vvv
    function testOnlyOwnerCanRemoveFromWhitelist() public {
        uint256[] memory actions = new uint256[](1);
        actions[0] = DEPOSIT_ACTION;
        
        address[] memory addresses = new address[](1);
        addresses[0] = _user1;
        
        // First add the address as owner
        vm.prank(_owner);
        _resolver.addToWhitelist(actions, addresses);
        
        // Try to remove as non-owner
        vm.prank(_user2);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _user2));
        _resolver.removeFromWhitelist(actions, addresses);
    }
    
    // FOUNDRY_PROFILE=core_test forge test --mt testEvents -vvv
    function testEvents() public {
        uint256[] memory actions = new uint256[](1);
        actions[0] = DEPOSIT_ACTION;
        
        address[] memory addresses = new address[](1);
        addresses[0] = _user1;
        
        // Test AddressAddedToWhitelist event
        vm.expectEmit(true, true, false, true);
        emit IWhitelistComplianceResolver.AddressAddedToWhitelist(DEPOSIT_ACTION, _user1);

        vm.prank(_owner);
        _resolver.addToWhitelist(actions, addresses);
        
        // Test AddressRemovedFromWhitelist event
        vm.expectEmit(true, true, false, true);
        emit IWhitelistComplianceResolver.AddressRemovedFromWhitelist(DEPOSIT_ACTION, _user1);

        vm.prank(_owner);
        _resolver.removeFromWhitelist(actions, addresses);
    }
    
    // FOUNDRY_PROFILE=core_test forge test --mt testCombinedActions -vvv
    function testCombinedActions() public {
        // Test with a bitwise combination of actions
        uint256 combinedAction = DEPOSIT_ACTION | BORROW_ACTION;
        
        uint256[] memory actions = new uint256[](1);
        actions[0] = combinedAction;
        
        address[] memory addresses = new address[](1);
        addresses[0] = _user1;

        vm.prank(_owner);
        _resolver.addToWhitelist(actions, addresses);
        
        // Verify user1 is in the whitelist for combinedAction
        assertTrue(_resolver.isInWhitelist(combinedAction, _user1));
        
        // Get whitelist for combinedAction and verify it contains user1
        address[] memory whitelist = _resolver.getWhitelist(combinedAction);
        assertEq(whitelist.length, 1);
        assertEq(whitelist[0], _user1);
    }
}
