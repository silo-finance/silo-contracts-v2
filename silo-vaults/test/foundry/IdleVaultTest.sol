// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {stdError} from "forge-std/StdError.sol";
import {Test} from "forge-std/Test.sol";

import {ERC20, ERC4626} from "openzeppelin5/token/ERC20/extensions/ERC4626.sol";
import {SafeCast} from "openzeppelin5/utils/math/SafeCast.sol";
import {IERC4626, IERC20} from "openzeppelin5/interfaces/IERC4626.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {MintableToken} from "silo-core/test/foundry/_common/MintableToken.sol";

import {ErrorsLib} from "../../contracts/libraries/ErrorsLib.sol";
import {EventsLib} from "../../contracts/libraries/EventsLib.sol";
import {ConstantsLib} from "../../contracts/libraries/ConstantsLib.sol";
import {IdleVault} from "../../contracts/IdleVault.sol";

import {IntegrationTest} from "./helpers/IntegrationTest.sol";
import {CAP, MAX_TEST_ASSETS, MIN_TEST_ASSETS, TIMELOCK} from "./helpers/BaseTest.sol";

contract ERC4626impl is ERC4626 {
    constructor(address _asset) ERC4626(IERC20(_asset)) ERC20("name", "symbol") {
    }
}
/*
 FOUNDRY_PROFILE=vaults-tests forge test --ffi --mc IdleVaultTest -vvv
*/
contract IdleVaultTest is Test {
    ERC4626 erc4626;
    IdleVault idleVault;
    MintableToken asset;
    
    address SUPPLIER = makeAddr("SUPPLIER");
    address attacker = makeAddr("attacker");

    function setUp() public {
        asset = new MintableToken(18);
        asset.setOnDemand(true);

        erc4626 = new ERC4626impl(address(asset));
        idleVault = new IdleVault(address(1), address(asset), "name", "symbol");
    }

    /*
    FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt test_idleVault_inflationAttackWithDonation -vvv
    */
    function test_idleVault_inflationAttackWithDonation(
//        uint64 attackerDeposit, uint64 supplierDeposit, uint64 donation
    ) public {
        (uint64 attackerDeposit, uint64 supplierDeposit, uint64 donation) = (12345, 3.5e18, 14e18);
        vm.assume(uint256(attackerDeposit) * supplierDeposit * donation != 0);
        vm.assume(supplierDeposit >= 2);

        vm.startPrank(attacker);
        idleVault.deposit(attackerDeposit, attacker);
        erc4626.deposit(attackerDeposit, attacker);
        vm.stopPrank();

        asset.transfer(address(idleVault), donation);
        asset.transfer(address(erc4626), donation);
        
        // we want cases where asset generates some shares
        vm.assume(idleVault.convertToShares(supplierDeposit) != 0);
        vm.assume(erc4626.convertToShares(supplierDeposit) != 0);

        vm.startPrank(SUPPLIER);
        idleVault.deposit(supplierDeposit, SUPPLIER);
        erc4626.deposit(supplierDeposit, SUPPLIER);

        uint256 attackerTotalSpend = uint256(donation) + attackerDeposit;

        vm.startPrank(attacker);
        uint256 attackerWithdrawIdle = idleVault.redeem(idleVault.balanceOf(attacker), attacker, attacker);
        uint256 attackerWithdrawErc = erc4626.redeem(erc4626.balanceOf(attacker), attacker, attacker);
        assertLe(attackerWithdrawIdle, attackerTotalSpend, "[idleVault] must be not profitable");
        assertLe(attackerWithdrawErc, attackerTotalSpend, "[erc4626] must be not profitable");
        vm.stopPrank();

        vm.startPrank(SUPPLIER);
        uint256 withdrawIdle = idleVault.redeem(idleVault.balanceOf(SUPPLIER), SUPPLIER, SUPPLIER);
        uint256 withdrawErc = erc4626.redeem(erc4626.balanceOf(SUPPLIER), SUPPLIER, SUPPLIER);
        vm.stopPrank();

        uint256 attackerTotalLossIdlePercent = (attackerTotalSpend - attackerWithdrawErc) * 1e18 / attackerTotalSpend;
        emit log_named_uint("[idleVault] ATTACKER loss", attackerTotalSpend - attackerWithdrawIdle);
        emit log_named_decimal_uint("[erc4626] ATTACKER lost [%]", attackerTotalLossIdlePercent, 16);

        assertGt(
            attackerTotalSpend - attackerWithdrawErc,
            attackerTotalSpend - attackerWithdrawIdle,
            "loss is greater on idle vault because of higher offset"
        );

        assertGt(attackerTotalLossIdlePercent, 0.99e18, "loss is greater than 99%");

        assertGe(
            withdrawIdle,
            withdrawErc,
            "idle vault allow to withdraw more ebcause of offset"
        );

        assertGe(
            withdrawIdle,
            supplierDeposit - 2,
            "[idle] SUPPLIER should not lost (2 wei acceptable for roundings)"
        );
    }

    /*
    FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt testInflationAttack_permanentLoss -vvv

    1. withdraw from idle
    2. inflate price
    3. deposit to idle (loss?): yes, it is the same as donation

    setting up 18 (or even 36 offset) prevent it (for idle vault)

    */
    function testInflationAttack_permanentLoss(
//        uint64 attackerDeposit, uint64 supplierDeposit, uint64 donation
    ) public {
        (uint64 attackerDeposit, uint64 supplierDeposit, uint64 donation) = (12345, 3.5e18, 14e18);
        vm.assume(uint256(attackerDeposit) * supplierDeposit * donation != 0);
        vm.assume(supplierDeposit >= 2);
//
//        // we want some founds to go to idle market, so cap must be lower than deposit
//        _setCap(allMarkets[0], supplierDeposit / 2);
//
//        vm.prank(SUPPLIER);
//        vault.deposit(supplierDeposit, SUPPLIER);
//
////        _printData("after supplier deposit");
//
//        // simulate realocation (withdraw from idle)
//        vm.startPrank(address(vault));
//        uint256 idleAmount = idleVault.redeem(idleVault.balanceOf(address(vault)), address(vault), address(vault));
//        vm.stopPrank();
//
////        _printData("state after realoction from idle");
//
//        address attacker = makeAddr("attacker");
//        IERC20(idleVault.asset()).transfer(address(idleVault), donation);
//
//
//        // simulate realocation back
//        vm.startPrank(address(vault));
//        idleVault.deposit(idleAmount, address(vault));
//        vm.stopPrank();

//        _printData("state after realocation back to idle");
    }
}