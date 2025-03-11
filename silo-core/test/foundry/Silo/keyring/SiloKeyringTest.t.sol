// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";
import {SiloLittleHelper} from "silo-core/test/foundry/_common/SiloLittleHelper.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IKeyringChecker} from "silo-core/contracts/interfaces/IKeyringChecker.sol";
import {IERC4626} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {KeyringCheckerMock} from "silo-core/test/foundry/_mocks/KeyringCheckerMock.sol";

contract SiloKeyringTest is SiloLittleHelper, IntegrationTest {
    string public constant SILO_TO_DEPLOY = SiloConfigsNames.SILO_LOCAL_NO_ORACLE_SILO;
    KeyringCheckerMock public keyringChecker;
    uint256 public constant TEST_POLICY_ID = 1;
    address siloConfigAddr;

    function setUp() public {
        // Deploy base setup using the helper
        _setUpLocalFixture();
        
        // Deploy mock keyring checker
        keyringChecker = new KeyringCheckerMock();
        
        // Store SiloConfig address
        siloConfigAddr = address(silo0.config());
    }

    /*
    FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt testOnlySiloConfigCanSetKeyring
    */
    function testOnlySiloConfigCanSetKeyring() public {
        // Try to set keyring config from non-SiloConfig address
        vm.expectRevert(IShareToken.OnlySiloConfig.selector);
        silo0.setKeyringConfig(address(keyringChecker), TEST_POLICY_ID);

        // Set it from SiloConfig address
        vm.prank(siloConfigAddr);
        silo0.setKeyringConfig(address(keyringChecker), TEST_POLICY_ID);
        
        // Verify it worked by trying a deposit (should fail due to not being whitelisted)
        uint256 depositAmount = 1000e18;
        deal(address(token0), address(this), depositAmount);
        token0.approve(address(silo0), depositAmount);
        
        vm.expectRevert(ISilo.OnlyKeyringWhitelisted.selector);
        silo0.deposit(depositAmount, address(this));
    }

    /*
    FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt testSetKeyringConfig
    */
    function testSetKeyringConfig() public {
        // Test setting keyring config
        vm.prank(siloConfigAddr);
        silo0.setKeyringConfig(address(keyringChecker), TEST_POLICY_ID);
        
        // Try to deposit with non-whitelisted address
        uint256 depositAmount = 1000e18;
        deal(address(token0), address(this), depositAmount);
        token0.approve(address(silo0), depositAmount);
        
        // Calculate expected shares before deposit
        uint256 expectedShares = silo0.previewDeposit(depositAmount);
        
        vm.expectRevert(ISilo.OnlyKeyringWhitelisted.selector);
        silo0.deposit(depositAmount, address(this));

        // Whitelist the address and try again
        keyringChecker.setWhitelisted(TEST_POLICY_ID, address(this), true);
        uint256 receivedShares = silo0.deposit(depositAmount, address(this));
        
        // Verify deposit was successful by checking received shares match expected shares
        assertEq(receivedShares, expectedShares, "Received shares should match preview");
        assertEq(silo0.balanceOf(address(this)), expectedShares, "Balance should match expected shares");
    }

    /*
    FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt testMultipleUsers
    */
    function testMultipleUsers() public {
        vm.prank(siloConfigAddr);
        silo0.setKeyringConfig(address(keyringChecker), TEST_POLICY_ID);
        
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");
        
        uint256 depositAmount = 1000e18;
        deal(address(token0), alice, depositAmount);
        deal(address(token0), bob, depositAmount);
        
        uint256 expectedShares = silo0.previewDeposit(depositAmount);
        
        vm.startPrank(alice);
        token0.approve(address(silo0), depositAmount);
        vm.expectRevert(ISilo.OnlyKeyringWhitelisted.selector);
        silo0.deposit(depositAmount, alice);
        vm.stopPrank();
        
        vm.startPrank(bob);
        token0.approve(address(silo0), depositAmount);
        vm.expectRevert(ISilo.OnlyKeyringWhitelisted.selector);
        silo0.deposit(depositAmount, bob);
        vm.stopPrank();
        
        // Whitelist only Alice
        keyringChecker.setWhitelisted(TEST_POLICY_ID, alice, true);
        
        // Alice should be able to deposit
        vm.prank(alice);
        uint256 receivedShares = silo0.deposit(depositAmount, alice);
        assertEq(receivedShares, expectedShares, "Received shares should match preview");
        assertEq(silo0.balanceOf(alice), expectedShares, "Balance should match expected shares");
        
        // Bob should still be blocked
        vm.startPrank(bob);
        vm.expectRevert(ISilo.OnlyKeyringWhitelisted.selector);
        silo0.deposit(depositAmount, bob);
        vm.stopPrank();
    }

    /*
    FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt testUpdateKeyringConfig
    */
    function testUpdateKeyringConfig() public {
        vm.prank(siloConfigAddr);
        silo0.setKeyringConfig(address(keyringChecker), TEST_POLICY_ID);
        
        // Whitelist user in first policy
        keyringChecker.setWhitelisted(TEST_POLICY_ID, address(this), true);
        
        uint256 depositAmount = 1000e18;
        deal(address(token0), address(this), depositAmount * 2); // Double the amount to handle both deposits
        token0.approve(address(silo0), depositAmount);
        
        uint256 expectedShares = silo0.previewDeposit(depositAmount);
        
        // Should work with first policy
        uint256 receivedShares = silo0.deposit(depositAmount, address(this));
        assertEq(receivedShares, expectedShares, "Received shares should match preview");
        
        // Change to new policy
        uint256 newPolicyId = 2;
        vm.prank(siloConfigAddr);
        silo0.setKeyringConfig(address(keyringChecker), newPolicyId);
        
        // Should fail with new policy (not whitelisted)
        vm.expectRevert(ISilo.OnlyKeyringWhitelisted.selector);
        silo0.deposit(depositAmount, address(this));
        
        // Whitelist in new policy
        keyringChecker.setWhitelisted(newPolicyId, address(this), true);
        
        // Approve tokens again for the second deposit
        token0.approve(address(silo0), depositAmount);
        
        // Should work again
        expectedShares = silo0.previewDeposit(depositAmount);
        receivedShares = silo0.deposit(depositAmount, address(this));
        assertEq(receivedShares, expectedShares, "Received shares should match preview");
    }
}