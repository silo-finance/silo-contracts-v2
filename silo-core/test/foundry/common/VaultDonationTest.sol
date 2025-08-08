pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {IERC4626, IERC20} from "openzeppelin5/interfaces/IERC4626.sol";

abstract contract VaultDonationTest is Test {
    IERC4626 public vault;
    
    function setUp() public virtual; // set vault address and donationAddress

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_vaultDonation_result_single -vvv 
    */
    function test_vaultDonation_result_single() public virtual {
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");

        uint256 donation = 100e18;
        uint256 deposit1 = 100e18;
        uint256 deposit2 = 100e18;

        _executeDonation(donation);

        vm.startPrank(user1);

        IERC20(vault.asset()).approve(address(vault), deposit1);
        uint256 shares1 = vault.deposit(deposit1, user1);

        vm.stopPrank();

        vm.startPrank(user2);

        IERC20(vault.asset()).approve(address(vault), deposit2);
        uint256 shares2 = vault.deposit(deposit2, user2);

        vm.stopPrank();

        uint256 ratio1 = shares1 * 1e18 / deposit1;
        uint256 ratio2 = shares2 * 1e18 / deposit2;

        console2.log("shares1 %s, ratio1 %s", shares1, ratio1);
        console2.log("shares2 %s, ratio2 %s", shares2, ratio2);

        assertEq(ratio1, ratio2, "expect the same ratio for both users even if there was donation");
    }

    function test_vaultDonation_result_fuzz(uint256 _donation, uint256 _deposit1, uint256 _deposit2) public {
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");

        _executeDonation(_donation);

        vm.startPrank(user1);

        IERC20(vault.asset()).approve(address(vault), _deposit1);
        uint256 shares1 = vault.deposit(_deposit1, user1);

        vm.stopPrank();

        vm.startPrank(user2);

        IERC20(vault.asset()).approve(address(vault), _deposit2);
        uint256 shares2 = vault.deposit(_deposit2, user2);

        vm.stopPrank();

        uint256 ratio1 = shares1 * 1e18 / _deposit1;
        uint256 ratio2 = shares2 * 1e18 / _deposit2;

        assertEq(ratio1, ratio2, "expect the same ratio for both users even if there was donation");
    }

    function _executeDonation(uint256 _donation) internal virtual;
}