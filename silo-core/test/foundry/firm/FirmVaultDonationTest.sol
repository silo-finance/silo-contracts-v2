pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {IERC4626, IERC20} from "openzeppelin5/interfaces/IERC4626.sol";

import {FirmVaultFactory} from "silo-core/contracts/firm/FirmVaultFactory.sol";

import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";

import {IRM} from "silo-core/contracts/firm/FirmVault.sol";

/*
    FOUNDRY_PROFILE=core_test forge test --ffi --mc FirmVaultDonationTest -vvv 
*/
contract FirmVaultDonationTest is SiloLittleHelper, Test {
    FirmVaultFactory factory = new FirmVaultFactory();
    IERC4626 public firmVault;

    function setUp() public {
        _setUpLocalFixture();

        token1.setOnDemand(true);

        firmVault = factory.create(address(this), silo1, bytes32(0));

        vm.mockCall(
            address(silo1.config().getConfig(address(silo1)).interestRateModel),
            abi.encodeWithSelector(IRM.pendingAccrueInterest.selector, block.timestamp),
            abi.encode(0)
        );
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_vaultDonation_result_single -vvv 
    */
    function test_vaultDonation_result_single() public virtual {
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");

        uint256 donation = 1e18;
        uint256 deposit1 = 2e18;
        uint256 deposit2 = 5e18;

        _executeDonation(donation);

        vm.startPrank(user1);

        IERC20(firmVault.asset()).approve(address(firmVault), deposit1);
        uint256 shares1 = firmVault.deposit(deposit1, user1);

        vm.stopPrank();

        vm.startPrank(user2);

        IERC20(firmVault.asset()).approve(address(firmVault), deposit2);
        uint256 shares2 = firmVault.deposit(deposit2, user2);

        vm.stopPrank();

        uint256 ratio1 = shares1 * 1e18 / deposit1;
        uint256 ratio2 = shares2 * 1e18 / deposit2;

        console2.log("shares1 %s, ratio1 %s", shares1, ratio1);
        console2.log("shares2 %s, ratio2 %s", shares2, ratio2);

        assertEq(ratio1, ratio2, "expect the same ratio for both users even if there was donation");

        // -1 because of rounding
        assertEq(firmVault.maxWithdraw(user1), donation + deposit1 - 1, "expect user1 to have the donation and deposit1");
        assertEq(firmVault.maxWithdraw(user2), deposit2, "expect user2 to have only the deposit2");
    }

    function test_vaultDonation_result_fuzz(uint256 _donation, uint256 _deposit1, uint256 _deposit2) public {
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");

        _executeDonation(_donation);

        vm.startPrank(user1);

        IERC20(firmVault.asset()).approve(address(firmVault), _deposit1);
        uint256 shares1 = firmVault.deposit(_deposit1, user1);

        vm.stopPrank();

        vm.startPrank(user2);

        IERC20(firmVault.asset()).approve(address(firmVault), _deposit2);
        uint256 shares2 = firmVault.deposit(_deposit2, user2);

        vm.stopPrank();

        uint256 ratio1 = shares1 * 1e18 / _deposit1;
        uint256 ratio2 = shares2 * 1e18 / _deposit2;

        assertEq(ratio1, ratio2, "expect the same ratio for both users even if there was donation");
    }

    function _executeDonation(uint256 _donation) internal {
        uint256 shares = _depositForBorrow(_donation, address(this));
        silo1.transfer(address(firmVault), shares);
    }
}