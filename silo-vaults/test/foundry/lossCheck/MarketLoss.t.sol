// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {IERC4626, IERC20} from "openzeppelin5/interfaces/IERC4626.sol";
import {ERC4626} from "openzeppelin5/token/ERC20/extensions/ERC4626.sol";
import {Math} from "openzeppelin5/utils/math/Math.sol";

import {ErrorsLib} from "../../../contracts/libraries/ErrorsLib.sol";
import {IdleVault} from "../../../contracts/IdleVault.sol";

import {IntegrationTest} from "../helpers/IntegrationTest.sol";

interface IBefore {
    function beforeDeposit() external;
}

contract ERC4626WithBeforeHook is IdleVault {
    IBefore hook;
    uint8 offset = 18; // default for idle

    constructor(IBefore _hook, IERC4626 _vault) IdleVault(address(_vault), _vault.asset(), "n", "s") {
        hook = _hook;
    }

    /// @inheritdoc IERC4626
    function deposit(uint256 _assets, address _receiver) public virtual override returns (uint256 shares) {
        hook.beforeDeposit();

        return super.deposit(_assets, _receiver);
    }

    function setOffset(uint8 _offset) external {
        require(totalSupply() == 0, "vault must be empty to set offset");
        offset = _offset;
    }
    
    function _decimalsOffset() internal view virtual override returns (uint8) {
        return offset;
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
        uint64 _attackerDeposit,
        uint64 _supplierDeposit,
        uint64 _donation,
        uint8 _idleVaultOffset
    ) public {
        // case where we can detect loss on market:
//        (uint64 _attackerDeposit,
//            uint64 _supplierDeposit,
//            uint64 _donation,
//            uint8 _idleVaultOffset) = (8707779, 9692708345249, 18446744073709551614, 0);

        _idleVault_InflationAttackWithDonation({
            _supplierWithdrawFirst: true,
            _attackOnBeforeDeposit: false,
            _attackerDeposit: _attackerDeposit,
            _supplierDeposit: _supplierDeposit,
            _donation: _donation,
            _idleVaultOffset: _idleVaultOffset,
            _acceptableLossThreshold: vault.ARBITRARY_LOSS_THRESHOLD()
        });
    }

    /*
    FOUNDRY_PROFILE=vaults-tests forge test --ffi --mc MarketLossTest --mt test_idleVault_hookAttackWithDonation_supplierFirst -vvv
    */
    /// forge-config: vaults-tests.fuzz.runs = 10000
    function test_idleVault_hookAttackWithDonation_supplierFirst(
        uint64 _attackerDeposit,
        uint64 _supplierDeposit,
        uint64 _donation,
        uint8 _idleVaultOffset
    ) public {
        // case where we can detect loss on market:
//        (uint64 _attackerDeposit,
//            uint64 _supplierDeposit,
//            uint64 _donation,
//            uint8 _idleVaultOffset) = (8707779, 9692708345249, 18446744073709551614, 0);

        _idleVault_InflationAttackWithDonation({
            _supplierWithdrawFirst: true,
            _attackOnBeforeDeposit: true,
            _attackerDeposit: _attackerDeposit,
            _supplierDeposit: _supplierDeposit,
            _donation: _donation,
            _idleVaultOffset: _idleVaultOffset,
            _acceptableLossThreshold: vault.ARBITRARY_LOSS_THRESHOLD()
        });
    }

    /*
    FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt test_idleVault_InflationAttackWithDonation_attackerFirst -vvv
    */
    /// forge-config: vaults-tests.fuzz.runs = 10000
    function test_idleVault_InflationAttackWithDonation_attackerFirst(
        uint64 _attackerDeposit,
        uint64 _supplierDeposit,
        uint64 _donation,
        uint8 _idleVaultOffset
    ) public {
        // when attacker withdraw first, loss is not detected, eg:
//        (
//            uint64 _attackerDeposit,
//            uint64 _supplierDeposit,
//            uint64 _donation,
//            uint8 _idleVaultOffset
//        ) = (38002435762126, 224063681149666585, 2013265765460, 5);

        _idleVault_InflationAttackWithDonation({
            _supplierWithdrawFirst: false,
            _attackOnBeforeDeposit: false,
            _attackerDeposit: _attackerDeposit,
            _supplierDeposit: _supplierDeposit,
            _donation: _donation,
            _idleVaultOffset: _idleVaultOffset,
            _acceptableLossThreshold: uint64(Math.max(vault.ARBITRARY_LOSS_THRESHOLD(), 1.3e15))
        });
    }

    /*
    FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt test_idleVault_hookAttackWithDonation_attackerFirst -vvv
    */
    /// forge-config: vaults-tests.fuzz.runs = 10000
    function test_idleVault_hookAttackWithDonation_attackerFirst(
        uint64 _attackerDeposit,
        uint64 _supplierDeposit,
        uint64 _donation,
        uint8 _idleVaultOffset
    ) public {
        _idleVault_InflationAttackWithDonation({
            _supplierWithdrawFirst: false,
            _attackOnBeforeDeposit: true,
            _attackerDeposit: _attackerDeposit,
            _supplierDeposit: _supplierDeposit,
            _donation: _donation,
            _idleVaultOffset: _idleVaultOffset,
            _acceptableLossThreshold: uint64(Math.max(vault.ARBITRARY_LOSS_THRESHOLD(), 1.3e15))
        });
    }

    function _idleVault_InflationAttackWithDonation(
        bool _supplierWithdrawFirst, 
        bool _attackOnBeforeDeposit, 
        uint64 _attackerDeposit,
        uint64 _supplierDeposit,
        uint64 _donation,
        uint8 _idleVaultOffset,
        uint64 _acceptableLossThreshold
    ) public {
        vm.assume(uint256(_attackerDeposit) * _supplierDeposit * _donation != 0);
        vm.assume(_supplierDeposit >= 2);
        vm.assume(_idleVaultOffset < 20);
        ERC4626WithBeforeHook(address(idleMarket)).setOffset(_idleVaultOffset);

        // we want some founds to go to idle market, so cap must be lower than deposit
        _setCap(allMarkets[0], _supplierDeposit / 2);

        vm.prank(attacker);
        vault.deposit(_attackerDeposit, attacker);

        // we want cases where asset generates some shares
        vm.assume(vault.convertToShares(_supplierDeposit) != 0);

        // to avoid losses caused by rounding error, recalculate assets
        emit log_named_uint("original _supplierDeposit", _supplierDeposit);
        emit log_named_uint("1 asset is this much shares before attack", vault.convertToShares(1));
        _supplierDeposit = uint64(vault.convertToAssets(vault.convertToShares(_supplierDeposit)));
        emit log_named_uint("recaulculared _supplierDeposit", _supplierDeposit);

        // here we have frontrun with donation
        if (_attackOnBeforeDeposit) donationAmount = _donation;
        else IERC20(idleMarket.asset()).transfer(address(idleMarket), _donation);

        vm.prank(SUPPLIER);

        emit log_named_address("IDLE MARKET", address(idleMarket));
        emit log(".......SUPPLIER doing deposit");

        try vault.deposit(_supplierDeposit, SUPPLIER) {
            // if did not revert, we expect no loss

            uint256 attackerTotalSpend = uint256(_donation) + _attackerDeposit;

            uint256 supplierWithdraw;
            uint256 attackerWithdraw;

            if (_supplierWithdrawFirst) {
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

            if (supplierWithdraw > _supplierDeposit) {
                emit log("there should be no gain for supplier on healthy markets, but we gain:");
                emit log_uint(supplierWithdraw - _supplierDeposit);
            }

            uint256 supplierLoss = _supplierDeposit < supplierWithdraw ? 0 : _supplierDeposit - supplierWithdraw;

            assertGe(
                attackerTotalLoss + 2,
                supplierLoss,
                "attacker pays for it (+2 because of rounding error, we accepting 2wei discrepancy)"
            );

            emit log_named_uint(" SUPPLIER deposit", _supplierDeposit);
            emit log_named_uint("SUPPLIER withdraw", supplierWithdraw);
            emit log_named_uint("    SUPPLIER loss", supplierLoss);
            emit log_named_uint("    attacker loss", attackerTotalLoss);

            uint256 supplierLostPercent = supplierLoss * 1e18 / _supplierDeposit;

            assertLt(
                supplierLoss,
                _acceptableLossThreshold,
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
        uint64 _supplierDeposit, uint64 donation
    ) public {
//        (uint64 _supplierDeposit, uint64 donation) = (104637192540, 2730, 18446744073709551615);
        vm.assume(uint256(_supplierDeposit) * donation != 0);
        vm.assume(_supplierDeposit >= 2);

        // we want some founds to go to idle market, so cap must be lower than deposit
        _setCap(allMarkets[0], _supplierDeposit / 2);

        vm.prank(SUPPLIER);
        vault.deposit(_supplierDeposit, SUPPLIER);

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

        uint256 supplierDiff = _supplierDeposit - supplierWithdraw;
        uint256 supplierLostPercent = supplierDiff * 1e18 / _supplierDeposit;
        emit log_named_uint("supplierLostPercent", supplierLostPercent);

        assertLe(
            supplierDiff,
            19, // NOTICE: 19 wei can be 50% loss for dust deposits
            "SUPPLIER should not lost (18 wei acceptable for fuzzing test to pass for extreme scenarios)"
        );
    }

    function _vaultWithdrawAll(address _user) internal returns (uint256 amount) {
        vm.startPrank(_user);
        amount = vault.maxRedeem(_user);
        emit log_named_uint("_vaultWithdrawAll", amount);
        if (amount == 0) return 0;

        amount = vault.redeem(vault.balanceOf(_user), _user, _user);
        vm.stopPrank();
    }
}
