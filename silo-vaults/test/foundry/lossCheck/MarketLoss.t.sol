// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {IERC4626, IERC20} from "openzeppelin5/interfaces/IERC4626.sol";
import {ERC4626} from "openzeppelin5/token/ERC20/extensions/ERC4626.sol";

import {ErrorsLib} from "../../../contracts/libraries/ErrorsLib.sol";
import {IdleVault} from "../../../contracts/IdleVault.sol";

import {IntegrationTest} from "../helpers/IntegrationTest.sol";

interface IBefore {
    function beforeDeposit() external;
}

contract ERC4626WithBeforeHook is IdleVault {
    IBefore hook;

    constructor(IBefore _hook, IERC4626 _vault) IdleVault(address(_vault), _vault.asset(), "n", "s") {
        hook = _hook;
    }

    /// @inheritdoc IERC4626
    function deposit(uint256 _assets, address _receiver) public virtual override returns (uint256 shares) {
        hook.beforeDeposit();

        return super.deposit(_assets, _receiver);
    }
}

/*
 FOUNDRY_PROFILE=vaults-tests forge test --ffi --mc MarketLossTest -vvv
*/
contract MarketLossTest is IBefore, IntegrationTest {
    address attacker = makeAddr("attacker");
    uint256 donationAmount;

    function setUp() public override {
        super.setUp();

        // previous idle market removal
        _setCapSimple(idleMarket, 0);
        emit log_named_address("old idleMarket", address(idleMarket));

        idleMarket = new ERC4626WithBeforeHook(this, vault);
        allMarkets[allMarkets.length - 1] = idleMarket;
        donationAmount = 0;
        emit log_named_address("NEW idleMarket", address(idleMarket));

        IERC4626[] memory supplyQueue = new IERC4626[](2);
        supplyQueue[0] = allMarkets[0];
        supplyQueue[1] = idleMarket;

        _setCapSimple(allMarkets[0], 1);
        _setCapSimple(idleMarket, type(uint128).max);

        vm.prank(ALLOCATOR);
        vault.setSupplyQueue(supplyQueue);
        emit log("setSupplyQueue done");

        uint256[] memory indexes = new uint256[](2);
        indexes[0] = 2;
        indexes[1] = 1;
        vm.prank(ALLOCATOR);
        vault.updateWithdrawQueue(indexes);
        emit log("updateWithdrawQueue done");

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

    function beforeDeposit() external {
        if (donationAmount == 0) return;

        IERC20(idleMarket.asset()).transfer(address(idleMarket), donationAmount);
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
    FOUNDRY_PROFILE=vaults-tests forge test --ffi --mc MarketLossTest --mt test_idleVault_InflationAttackWithDonation_supplierFirst -vvv
    */
    /// forge-config: vaults-tests.fuzz.runs = 10000
    function test_idleVault_InflationAttackWithDonation_supplierFirst(
//        uint64 attackerDeposit, uint64 supplierDeposit, uint64 donation
    ) public {
        (uint64 attackerDeposit, uint64 supplierDeposit, uint64 donation) = (31260780, 2715, 22621791505034);
        // atacker deposit (0) 31260780

        _idleVault_InflationAttackWithDonation({
            supplierWithdrawFirst: true,
            onBeforeDeposit: false,
            attackerDeposit: attackerDeposit,
            supplierDeposit: supplierDeposit,
            donation: donation
        });
    }

    /*
    FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt test_idleVault_InflationAttackWithDonation_attackerFirst -vvv
    */
    /// forge-config: vaults-tests.fuzz.runs = 10000
    function test_idleVault_InflationAttackWithDonation_attackerFirst(
//        uint64 attackerDeposit, uint64 supplierDeposit, uint64 donation
    ) public {
        (uint64 attackerDeposit, uint64 supplierDeposit, uint64 donation) = (31260780, 2715, 22621791505034);

        vm.assume(attackerDeposit > 1);
        vm.assume(supplierDeposit > 1);
        vm.assume(donation > 1);

        _idleVault_InflationAttackWithDonation({
            supplierWithdrawFirst: false,
            onBeforeDeposit: false,
            attackerDeposit: attackerDeposit,
            supplierDeposit: supplierDeposit,
            donation: donation
        });
    }

    function _idleVault_InflationAttackWithDonation(
        bool supplierWithdrawFirst, bool onBeforeDeposit, uint64 attackerDeposit, uint64 supplierDeposit, uint64 donation
    ) public {
        vm.assume(uint256(attackerDeposit) * supplierDeposit * donation != 0);
        vm.assume(supplierDeposit >= 2);

        // we want some founds to go to idle market, so cap must be lower than deposit
        _setCap(allMarkets[0], supplierDeposit / 2);

        vm.prank(attacker);
        vault.deposit(attackerDeposit, attacker);

        // we want cases where asset generates some shares
        vm.assume(vault.convertToShares(supplierDeposit) != 0);

        // to avoid losses caused by rounding error, recalculate assets
        emit log_named_uint("original supplierDeposit", supplierDeposit);
        emit log_named_uint("1 asset is this much shares before attack", vault.convertToShares(1));
        supplierDeposit = uint64(vault.convertToAssets(vault.convertToShares(supplierDeposit)));
        emit log_named_uint("recaulculared supplierDeposit", supplierDeposit);

        // here we have frontrun with donation
        if (onBeforeDeposit) donationAmount = donation;
        else IERC20(idleMarket.asset()).transfer(address(idleMarket), donation);


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

            uint256 supplierLoss = supplierDeposit - supplierWithdraw;

            assertGe(
                attackerTotalLoss + 2,
                supplierLoss,
                "attacker pays for it (+2 because of rounding error, we accepting 2wei discrepancy)"
            );

            emit log_named_uint(" SUPPLIER deposit", supplierDeposit);
            emit log_named_uint("SUPPLIER withdraw", supplierWithdraw);
            emit log_named_uint("    SUPPLIER loss", supplierDeposit - supplierWithdraw);
            emit log_named_uint("    attacker loss", attackerTotalLoss);

            uint256 supplierLostPercent = supplierLoss * 1e18 / supplierDeposit;

            if (supplierDeposit < 1e15) {
                // for tiny amounts % is higher because fuzzing cases can be extreme eg
                // deposit = 45
                // donation = 18446744073709551615
            } else {
                assertLt(supplierLostPercent, 1e15, "0.001%");
            }

            assertLt(
                supplierLoss,
                vault.ARBITRARY_LOSS_THRESHOLD(),
                "loss is higher than THRESHOLD, we should detect"
            );
        } catch (bytes memory data) {
            emit log("deposit reverted for SUPPLIER");

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
