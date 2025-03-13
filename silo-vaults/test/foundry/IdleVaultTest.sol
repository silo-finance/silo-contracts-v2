// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {IERC4626, IERC20} from "openzeppelin5/interfaces/IERC4626.sol";

import {ErrorsLib} from "../../contracts/libraries/ErrorsLib.sol";

import {IntegrationTest} from "./helpers/IntegrationTest.sol";

/*
 FOUNDRY_PROFILE=vaults-tests forge test --ffi --mc IdleVaultTest -vvv
*/
contract IdleVaultTest is IntegrationTest {
    address attacker = makeAddr("attacker");

    function setUp() public override {
        super.setUp();

        IERC4626[] memory supplyQueue = new IERC4626[](2);
        supplyQueue[0] = allMarkets[0];
        supplyQueue[1] = idleMarket;

        _setCap(allMarkets[0], 1);
        _setCap(idleMarket, type(uint128).max);

        vm.prank(ALLOCATOR);
        vault.setSupplyQueue(supplyQueue);

//        uint256[] memory indexes = new uint256[](2);
//        indexes[0] = 0;
//        indexes[1] = 1;
//        vm.prank(ALLOCATOR);
//        vault.updateWithdrawQueue(indexes);

        assertEq(vault.supplyQueueLength(), 2, "only 2 markets");
        assertEq(vault.withdrawQueueLength(), 2, "only 2 markets on withdraw");

        assertEq(address(vault.supplyQueue(1)), address(idleMarket), "ensure we have idle");

        assertEq(
            address(vault.withdrawQueue(0)),
            address(idleMarket),
            "ensure we have idle at begin, so when we withdraw, we do it from 'invalid` market first"
        );
    }

    /*
        FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt test_idleVault_minDepositWithOffset -vvv
    */
    function test_idleVault_minDepositWithOffset() public {
        address v = address(vault);

        vm.startPrank(v);
        idleMarket.deposit(1, v);

        idleMarket.deposit(1, v);

        assertEq(idleMarket.redeem(idleMarket.balanceOf(v), v, v), 2, "expect no loss on tiny deposit");
        vm.stopPrank();
    }

    /*
        FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt test_idleVault_offset -vv
    */
    function test_idleVault_offset() public {
        vm.prank(address(vault));
        uint256 shares = idleMarket.deposit(1, address(vault));
        assertEq(shares, 1e18, "big offset");
    }

    /*
    FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt test_idleVault_InflationAttackWithDonation_supplierFirst -vvv
    */
    /// forge-config: vaults-tests.fuzz.runs = 1000
    function test_idleVault_InflationAttackWithDonation_supplierFirst(
        uint64 attackerDeposit, uint64 supplierDeposit, uint64 donation
    ) public {
//        (uint64 attackerDeposit, uint64 supplierDeposit, uint64 donation) = (35277, 418781076350872, 18446744073709551613);

        _idleVault_InflationAttackWithDonation({
            supplierWithdrawFirst: true,
            _lossThreshold: 10,
            attackerDeposit: attackerDeposit,
            supplierDeposit: supplierDeposit,
            donation: donation
        });
    }

    /*
    FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt test_idleVault_InflationAttackWithDonation_attackerFirst -vvv
    */
    function test_idleVault_InflationAttackWithDonation_attackerFirst(
//        uint64 attackerDeposit, uint64 supplierDeposit, uint64 donation
    ) public {
        (uint64 attackerDeposit, uint64 supplierDeposit, uint64 donation) = (308496185, 681844, 20_2884268016093027);

        vm.assume(attackerDeposit > 1);
        vm.assume(supplierDeposit > 1);
        vm.assume(donation > 1);

        _idleVault_InflationAttackWithDonation({
            supplierWithdrawFirst: false,
            // bit weird, that loss can happen later for input:
            // (31260780, 2715, 22621791505034)
            _lossThreshold: 545,
            attackerDeposit: attackerDeposit,
            supplierDeposit: supplierDeposit,
            donation: donation
        });
    }

    function _idleVault_InflationAttackWithDonation(
        bool supplierWithdrawFirst, uint256 _lossThreshold, uint64 attackerDeposit, uint64 supplierDeposit, uint64 donation
    ) public {
        vm.assume(uint256(attackerDeposit) * supplierDeposit * donation != 0);
        vm.assume(supplierDeposit >= 2);

        // we want some founds to go to idle market, so cap must be lower than deposit
        _setCap(allMarkets[0], supplierDeposit / 2);

        vm.prank(attacker);
        vault.deposit(attackerDeposit, attacker);

        IERC20(idleMarket.asset()).transfer(address(idleMarket), donation);

        // we want cases where asset generates some shares
        vm.assume(vault.convertToShares(supplierDeposit) != 0);

        vm.prank(SUPPLIER);

        emit log_named_address("IDLE MARKET", address(idleMarket));
        emit log(".......SUPPLIER doing deposit");

        try vault.deposit(supplierDeposit, SUPPLIER) {
            // if did not revert, we expect no loss

            uint256 attackerTotalSpend = uint256(donation) + attackerDeposit;

            uint256 supplierWithdraw;
            uint256 attackerWithdraw;

            if (supplierWithdrawFirst) {
                emit log(".......SUPPLIER withdraw");
                supplierWithdraw = _vaultWithdrawAll(SUPPLIER);
                emit log(".......SUPPLIER withdraw END");

                attackerWithdraw = _vaultWithdrawAll(attacker);
            } else {
                attackerWithdraw = _vaultWithdrawAll(attacker);
                supplierWithdraw = _vaultWithdrawAll(SUPPLIER);
            }

            assertLe(attackerWithdraw, attackerTotalSpend, "must be not profitable");

            uint256 attackerTotalLoss = attackerTotalSpend - attackerWithdraw;
            uint256 attackerTotalLossPercent = attackerTotalLoss * 1e18 / uint256(attackerTotalSpend);
            emit log_named_decimal_uint("attackerTotalLossPercent", attackerTotalLossPercent, 16);

            uint256 supplierDiff = supplierDeposit - supplierWithdraw;

            assertGe(
                attackerTotalLoss + 2,
                supplierDiff,
                "attacker pays for it (+2 because of rounding error, we accepting 2wei discrepancy)"
            );

            /*
             emit Withdraw(
             caller: SiloVault: [0x550E4d0a372a64F14B7433DbAF4719398F767C31],
             receiver: SiloVault: [0x550E4d0a372a64F14B7433DbAF4719398F767C31],
             owner: SiloVault: [0x550E4d0a372a64F14B7433DbAF4719398F767C31],
             assets: 657655 [6.576e5], shares: 998893861115099
            */
            emit log_named_uint(" SUPPLIER deposit", supplierDeposit);
            emit log_named_uint("SUPPLIER withdraw", supplierWithdraw);
            emit log_named_uint("    SUPPLIER loss", supplierDeposit - supplierWithdraw);
            emit log_named_uint("    attacker loss", attackerTotalLoss);

            uint256 supplierLostPercent = supplierDiff * 1e18 / supplierDeposit;

            if (supplierDeposit < 1e15) {
                // for tiny amounts % is higher because fuzzing cases can be extreme eg
                // deposit = 45
                // donation = 18446744073709551615
            } else {
                assertLt(supplierLostPercent, 1e15, "0.001%");
            }

            assertLe(
                supplierDiff,
                _lossThreshold,
                "we should detect loss (some wei acceptable for fuzzing test to pass for extreme scenarios)"
            );
        } catch (bytes memory data) {
            bytes4 errorType = bytes4(data);
            assertEq(errorType, ErrorsLib.AssetLoss.selector, "AssetLoss is only acceptable revert here");
        }
    }

    /*
    FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt test_idleVault_InflationAttack_permanentLoss -vvv

    1. withdraw from idle
    2. inflate price
    3. deposit to idle (loss?): yes, it is the same as donation

    */
    function test_idleVault_InflationAttack_permanentLoss(
        uint64 supplierDeposit, uint64 donation
    ) public {
//        (uint64 supplierDeposit, uint64 donation) = (104637192540, 2730, 18446744073709551615);
        vm.assume(uint256(supplierDeposit) * donation != 0);
        vm.assume(supplierDeposit >= 2);

        // we want some founds to go to idle market, so cap must be lower than deposit
        _setCap(allMarkets[0], supplierDeposit / 2);

        vm.prank(SUPPLIER);
        vault.deposit(supplierDeposit, SUPPLIER);

        // simulate reallocation (withdraw from idle)
        vm.startPrank(address(vault));
        uint256 idleAmount = idleMarket.redeem(idleMarket.balanceOf(address(vault)), address(vault), address(vault));
        vm.stopPrank();

        // inflate price
        IERC20(idleMarket.asset()).transfer(address(idleMarket), donation);

        // simulate reallocation back
        vm.startPrank(address(vault));
        idleMarket.deposit(idleAmount, address(vault));
        vm.stopPrank();

        vm.startPrank(SUPPLIER);
        uint256 supplierWithdraw = vault.redeem(vault.balanceOf(SUPPLIER), SUPPLIER, SUPPLIER);
        vm.stopPrank();

        uint256 supplierDiff = supplierDeposit - supplierWithdraw;
        uint256 supplierLostPercent = supplierDiff * 1e18 / supplierDeposit;
        emit log_named_uint("supplierLostPercent", supplierLostPercent);

        assertLe(
            supplierDiff,
            19, // NOTICE: 19 wei can be 50% loss for dust deposits
            "SUPPLIER should not lost (18 wei acceptable for fuzzing test to pass for extreme scenarios)"
        );
    }

    function _vaultWithdrawAll(address _user) internal returns (uint256 amount) {
        vm.startPrank(_user);
        amount = vault.redeem(vault.balanceOf(_user), _user, _user);
        emit log_named_uint("_vaultWithdrawAll", amount);
        vm.stopPrank();
    }
}
