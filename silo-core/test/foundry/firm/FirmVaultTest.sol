// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

import {FirmVaultFactory} from "silo-core/contracts/firm/FirmVaultFactory.sol";

import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";

import {IRM} from "silo-core/contracts/firm/FirmVault.sol";

/*
 FOUNDRY_PROFILE=core_test forge test --ffi --mc FirmVaultTest -vvv 
*/
contract FirmVaultTest is SiloLittleHelper, Test {
    IERC4626 public firmVault;
    FirmVaultFactory factory = new FirmVaultFactory();

    function setUp() public {
        _setUpLocalFixture();

        token0.setOnDemand(true);
        token1.setOnDemand(true);

        firmVault = factory.create(address(this), silo1, bytes32(0));

        vm.label(address(firmVault), "firmVault");

        // TODO remove this when we have real IRM 
        vm.mockCall(
            address(silo1.config().getConfig(address(silo1)).interestRateModel),
            abi.encodeWithSelector(IRM.pendingAccrueInterest.selector, block.timestamp),
            abi.encode(0)
        );
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_firmVault_happyPath -vvv 
    */
    function test_firmVault_happyPath() public {
        address user = makeAddr("user");

        firmVault.mint(100e18, user);

        uint256 shares = firmVault.balanceOf(user);
        uint256 maxWithdraw = firmVault.maxWithdraw(user);

        vm.prank(user);
        assertEq(maxWithdraw, firmVault.redeem(shares, user, user), "expect happy path works");
    }
}
