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

        uint256[] memory indexes = new uint256[](2);
        indexes[0] = 2;
        indexes[1] = 1;
        vm.prank(ALLOCATOR);
        vault.updateWithdrawQueue(indexes);

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

        emit log_named_uint("executing donation attack with amount", donationAmount);
        IERC20(idleMarket.asset()).transfer(address(idleMarket), donationAmount);
    }

    /*
        FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt test_idleVault_offset -vv
    */
    function test_idleVault_offset() public {
        vm.prank(address(vault));
        uint256 shares = idleMarket.deposit(1, address(vault));
        assertEq(shares, 1e18, "expect big offset");
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
            _idleVaultOffset: _idleVaultOffset
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
            _idleVaultOffset: _idleVaultOffset
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
        _idleVault_InflationAttackWithDonation({
            _supplierWithdrawFirst: false,
            _attackOnBeforeDeposit: false,
            _attackerDeposit: _attackerDeposit,
            _supplierDeposit: _supplierDeposit,
            _donation: _donation,
            _idleVaultOffset: _idleVaultOffset
        });
    }

    /*
        If market offset is 0 it is possible to do an attack where attacker will lose less than supplier
        but supplier in that case loosing around 50% while attacker more than 64% (this is the lowest number that I was able to find).
        Our protection checks are disabled.
        Decimals in the silo vault has no effect on the attack.
        If enable protection checks, I was not able to find a case where attacker loss is less than supplier loss.

        The issue with the Silo Vault is only when underlying marker has higher decimals then the vault

        no global check and test found a case where attacker loss is less than supplier loss
        SUPPLIER loss: 5703.455581
        attacker loss: 3029.080927

        attackerTotalLossPercent: 98.5440320776791098
        SUPPLIER deposit: 0.429370
        SUPPLIER withdraw: 0.214685
        SUPPLIER loss: 0.214685
        attacker loss: 0.191204
        attacker spend: 0.194029

        attackerTotalLossPercent: 94.9036255068322809
        SUPPLIER deposit: 7.997358
        SUPPLIER withdraw: 3.998679
        SUPPLIER loss: 3.998679
        attacker loss: 2.532303
        attacker spend: 2.668289





        // with ratio no offset
        deposit 100
        deposit 100

        total shares: 200
        total assets: 200

        ration assets:share 200 / 200 = 1
        ration assets:share 100 / 100 = 1

        donation 1

        total shares: 200
        total assets: 201

        ration assets:share 201 / 200 = 1.005
        ration assets:share 100 / 100 = 1

        deposit 10
        shares 10 * 200 / 201 = 9.95

        ration 10 / 9.95 = 1.005

        function _convertToShares(uint256 assets, Math.Rounding rounding) internal view virtual returns (uint256) {
            return assets.mulDiv(totalSupply() + 10 ** _decimalsOffset(), totalAssets() + 1, rounding);
        }

        function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view virtual returns (uint256) {
            return shares.mulDiv(totalAssets() + 1, totalSupply() + 10 ** _decimalsOffset(), rounding);
        }
        // with ratio with offset 0
        deposit 100
        shares 100 * (0 + 1) / (0 + 1) = 100

        deposit 100
        shares 100 * (100 + 1) / (100 + 1) = 100

        donation 1

        total shares: 200
        total assets: 201

        ration assets:share 201 / 200 = 1.005

        deposit 10
        shares 10 * (201 + 1) / (200 + 1) = 10.05

        user ratio assets:share 10 / 10.05 = 0.995

        total shares: 210.05
        total assets: 211

        market ratio assets:share 211 / 210.05 = 1.005

        // with ratio with offset 0
        deposit 100
        shares 100 * (0 + 1) / (0 + 1) = 100

        deposit 100
        shares 100 * (100 + 1) / (100 + 1) = 100

        donation 50

        total shares: 200
        total assets: 250

        ration assets:share 250 / 200 = 1.25

        deposit 10
        shares 10 * (250 + 1) / (200 + 1) = 12.487562189054726

        user ratio assets:share 10 / 12.487562189054726 = 0.801

        total shares: 212.487562189054726
        total assets: 260

        market ratio assets:share 260 / 212.487562189054726 = 1.223

        redeem 12.487562189054726
        assets 12.487562189054726 * (260 + 1) / (212.487562189054726 + 1) = 15.266714828365687

        */

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
            _idleVaultOffset: _idleVaultOffset
        });
    }

    /*
    FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt test_idleVault_hookAttackWithDonation_attackerFirst32 -vvv
    */
    function test_idleVault_hookAttackWithDonation_attackerFirst32() public {
        uint64 _attackerDeposit = 26;
        uint64 _supplierDeposit = 10886;
        uint64 _donation = 17252;

        _idleVault_InflationAttackWithDonationTest2({
            _attackerDeposit: _attackerDeposit,
            _supplierDeposit: _supplierDeposit,
            _donation: _donation
        });
    }

    /*
    FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt test_idleVault_InflationAttackWithDonation_attackerFirst_lossAfter -vvv
    */
     function test_idleVault_InflationAttackWithDonation_attackerFirst_lossAfter() public {
        uint64 _attackerDeposit = 103;
        uint64 _supplierDeposit = 2237556296591692371;
        uint64 _donation = 7556575912; // to Idle Vault
        uint8 _idleVaultOffset = 1;


        /**
        supply queue
        market 0
        idle vault

        withdraw queue
        idle vault
        market 0

        cap idle vault = max
         market 0 = _supplierDeposit / 2

        // checks on this deposit _supplierDeposit
        vault offset 0  market offset 0 - AssetLossMarket
        vault offset 0  market offset 1 - not detected and supplier loose after
        vault offset 1  market offset 0 - AssetLossMarket
        vault offset 1  market offset 1 - not detected and supplier loose after
        vault offset 2  market offset 1 - not detected and supplier loose after
        vault offset 18  market offset 1 - not detected and supplier loose after
        vault offset 18  market offset 18 - not detected no loss
         */

        _idleVault_InflationAttackWithDonation({
            _supplierWithdrawFirst: false,
            _attackOnBeforeDeposit: false,
            _attackerDeposit: _attackerDeposit,
            _supplierDeposit: _supplierDeposit,
            _donation: _donation,
            _idleVaultOffset: _idleVaultOffset
        });
    }

    /*
    FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt test_idleVault_hookAttackWithDonation_attackerFirstGlobalLoss -vvv
    */
    function test_idleVault_hookAttackWithDonation_attackerFirstGlobalLoss() public {
        uint64 _attackerDeposit = 5216;
        uint64 _supplierDeposit = 10118;
        uint64 _donation = 16183;

        /*
        Both checks enabled:
        vault offset 0  market offset 0  - AssetLossMarket
        vault offset 0  market offset 18 - AssetLossGlobal
        vault offset 18 market offset 0  - AssetLossMarket
        vault offset 18 market offset 18 - not detected

        Only global check enabled:
        vault offset 0  market offset 0  - AssetLossGlobal
        vault offset 0  market offset 18 - AssetLossGlobal
        vault offset 18 market offset 0  - not detected
        vault offset 18 market offset 18 - not detected

        Only market check enabled:
        vault offset 0  market offset 0  - AssetLossMarket
        vault offset 0  market offset 18 - not detected
        vault offset 18 market offset 0  - AssetLossMarket
        vault offset 18 market offset 18 - not detected

        */

        _idleVault_InflationAttackWithDonationTest2({
            _attackerDeposit: _attackerDeposit,
            _supplierDeposit: _supplierDeposit,
            _donation: _donation
        });
    }

    function _idleVault_InflationAttackWithDonationTest2(
        uint64 _attackerDeposit,
        uint64 _supplierDeposit,
        uint64 _donation
    ) public {
        ERC4626WithBeforeHook(address(idleMarket)).setOffset(0);

        // we want some founds to go to idle market, so cap must be lower than supplier deposit
        _setCap(allMarkets[0], _supplierDeposit / 2);

        vm.assume(vault.convertToShares(_attackerDeposit) != 0);

        vm.prank(attacker);
        vault.deposit(_attackerDeposit, attacker);

        // to avoid losses caused by rounding error, recalculate assets
        _supplierDeposit = uint64(vault.convertToAssets(vault.convertToShares(_supplierDeposit)));

        // here we have frontrun with donation
        IERC20(idleMarket.asset()).transfer(address(idleMarket), _donation);

        vm.prank(SUPPLIER);
        vault.deposit(_supplierDeposit, SUPPLIER);
    }

    function _idleVault_InflationAttackWithDonation(
        bool _supplierWithdrawFirst, 
        bool _attackOnBeforeDeposit, 
        uint64 _attackerDeposit,
        uint64 _supplierDeposit,
        uint64 _donation,
        uint8 _idleVaultOffset
    ) public {
        vm.assume(uint256(_attackerDeposit) * _supplierDeposit * _donation != 0);
        vm.assume(_supplierDeposit >= 2);
        vm.assume(_idleVaultOffset < 20);
        ERC4626WithBeforeHook(address(idleMarket)).setOffset(_idleVaultOffset);

        // we want some founds to go to idle market, so cap must be lower than supplier deposit
        _setCap(allMarkets[0], _supplierDeposit / 2);

        vm.assume(vault.convertToShares(_attackerDeposit) != 0);

        vm.prank(attacker);
        vault.deposit(_attackerDeposit, attacker);

        emit log_string("--------------------------------PRINTING STATE--------------------------------");

        emit log_named_uint("attackerDeposit", _attackerDeposit);
        emit log_named_uint("supplierDeposit", _supplierDeposit);
        emit log_named_uint("donation", _donation);
        emit log_named_uint("asset balance market[0]", IERC20(idleMarket.asset()).balanceOf(address(allMarkets[0])));
        emit log_named_uint("asset balance idleMarket", IERC20(idleMarket.asset()).balanceOf(address(idleMarket)));

        emit log_string("--------------------------------after attacker deposit--------------------------------");

        emit log_named_uint("vault.totalAssets()", vault.totalAssets());
        emit log_named_uint("vault.totalSupply()", vault.totalSupply());

        emit log_named_uint("attacker shares", vault.balanceOf(attacker));
        emit log_named_uint("supplier shares", vault.balanceOf(SUPPLIER));

        emit log_named_uint("asset balance market[0]", IERC20(idleMarket.asset()).balanceOf(address(allMarkets[0])));
        emit log_named_uint("asset balance idleMarket", IERC20(idleMarket.asset()).balanceOf(address(idleMarket)));

        // to avoid losses caused by rounding error, recalculate assets
        // emit log_named_uint("original _supplierDeposit", _supplierDeposit);
        _supplierDeposit = uint64(vault.convertToAssets(vault.convertToShares(_supplierDeposit)));
        // emit log_named_uint("recalculated _supplierDeposit", _supplierDeposit);

        // here we have frontrun with donation
        if (_attackOnBeforeDeposit) donationAmount = _donation;
        else IERC20(idleMarket.asset()).transfer(address(idleMarket), _donation);

        emit log_string("--------------------------------after donation--------------------------------");

        emit log_named_uint("vault.totalAssets()", vault.totalAssets());
        emit log_named_uint("vault.totalSupply()", vault.totalSupply());

        // we want cases where asset generates some shares
        vm.assume(vault.convertToShares(_supplierDeposit) != 0);

        vm.prank(SUPPLIER);

        // emit log("SUPPLIER doing deposit");

        emit log_string("--------------------------------supplier deposit--------------------------------");

        try vault.deposit(_supplierDeposit, SUPPLIER) {
            // if did not revert, we expect no loss

            emit log_string("--------------------------------after supplier deposit--------------------------------");

            emit log_named_uint("vault.totalAssets()", vault.totalAssets());
            emit log_named_uint("vault.totalSupply()", vault.totalSupply());

            emit log_named_uint("attacker shares", vault.balanceOf(attacker));
            emit log_named_uint("supplier shares", vault.balanceOf(SUPPLIER));

            emit log_named_uint("asset balance market[0]", IERC20(idleMarket.asset()).balanceOf(address(allMarkets[0])));
            emit log_named_uint("asset balance idleMarket", IERC20(idleMarket.asset()).balanceOf(address(idleMarket)));

            uint256 attackerTotalSpend = uint256(_donation) + _attackerDeposit;

            uint256 supplierWithdraw;
            uint256 attackerWithdraw;

            if (_supplierWithdrawFirst) {
                emit log(".......SUPPLIER withdraw");
                supplierWithdraw = _vaultWithdrawAll(SUPPLIER);
                attackerWithdraw = _vaultWithdrawAll(attacker);
            } else {
                emit log_string("--------------------------------attacker withdraw--------------------------------");
                uint256 balanceIdle = IERC20(idleMarket.asset()).balanceOf(address(idleMarket));
                uint256 balanceMarket = IERC20(idleMarket.asset()).balanceOf(address(allMarkets[0]));
                emit log_named_uint("asset balance market[0]", balanceMarket);
                emit log_named_uint("asset balance idleMarket", balanceIdle);
                emit log_named_uint("asset balance total", balanceMarket + balanceIdle);
                attackerWithdraw = _vaultWithdrawAll(attacker);
                emit log_string("--------------------------------after attacker withdraw--------------------------------");
                emit log_named_uint("vault.totalAssets()", vault.totalAssets());
                emit log_named_uint("vault.totalSupply()", vault.totalSupply());

                emit log_named_uint("attacker shares", vault.balanceOf(attacker));
                emit log_named_uint("supplier shares", vault.balanceOf(SUPPLIER));

                emit log_named_uint("asset balance market[0]", IERC20(idleMarket.asset()).balanceOf(address(allMarkets[0])));
                emit log_named_uint("asset balance idleMarket", IERC20(idleMarket.asset()).balanceOf(address(idleMarket)));

                emit log_string("--------------------------------supplier withdraw--------------------------------");
                balanceIdle = IERC20(idleMarket.asset()).balanceOf(address(idleMarket));
                balanceMarket = IERC20(idleMarket.asset()).balanceOf(address(allMarkets[0]));
                emit log_named_uint("asset balance market[0]", balanceMarket);
                emit log_named_uint("asset balance idleMarket", balanceIdle);
                emit log_named_uint("asset balance total", balanceMarket + balanceIdle);

                supplierWithdraw = _vaultWithdrawAll(SUPPLIER);

                emit log_string("--------------------------------after supplier withdraw--------------------------------");
                emit log_named_uint("vault.totalAssets()", vault.totalAssets());
                emit log_named_uint("vault.totalSupply()", vault.totalSupply());

                emit log_named_uint("attacker shares", vault.balanceOf(attacker));
                emit log_named_uint("supplier shares", vault.balanceOf(SUPPLIER));

                emit log_named_uint("asset balance market[0]", IERC20(idleMarket.asset()).balanceOf(address(allMarkets[0])));
                emit log_named_uint("asset balance idleMarket", IERC20(idleMarket.asset()).balanceOf(address(idleMarket)));
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

            emit log_named_uint("offset", _idleVaultOffset);
            emit log_named_decimal_uint("SUPPLIER deposit", _supplierDeposit, 6);
            emit log_named_decimal_uint("SUPPLIER withdraw", supplierWithdraw, 6);
            emit log_named_decimal_uint("    SUPPLIER loss", supplierLoss, 6);
            emit log_named_decimal_uint("    attacker loss", attackerTotalLoss, 6);
            emit log_named_decimal_uint("    attacker spend", attackerTotalSpend, 6);

            uint256 supplierLostPercent = supplierLoss * 1e18 / _supplierDeposit;

            if (supplierLoss == 0 || attackerTotalLoss == 0) return;

            // vm.assume(supplierLoss == 1e6);

            // assertLe(supplierLoss, 1e6, "supplierLoss");
            // assertLe(supplierLoss, 2, "supplierLoss");

            assertLe(
                supplierLoss,
                vault.ARBITRARY_LOSS_THRESHOLD(),
                "loss is higher than THRESHOLD, we should detect"
            );

        } catch (bytes memory data) {
            emit log("deposit reverted for SUPPLIER");

            bytes4 errorType = bytes4(data);
            assertEq(errorType, ErrorsLib.AssetLoss.selector, "AssetLoss is only acceptable revert here");
        }

        // assertTrue(atLeastOneDeposit, "at least one deposit must be successful");
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
