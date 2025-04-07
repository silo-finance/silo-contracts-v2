// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries
import "forge-std/console.sol";
import {UtilsLib} from "morpho-blue/libraries/UtilsLib.sol";

// Test Contracts
import {BaseHooks} from "../base/BaseHooks.t.sol";

// Interfaces
import {IERC4626, IERC20} from "openzeppelin5/interfaces/IERC4626.sol";
import {IERC20Handler} from "../handlers/interfaces/IERC20Handler.sol";
import {ISiloVaultHandler} from "../handlers/interfaces/ISiloVaultHandler.sol";

/// @title Default Before After Hooks
/// @notice Helper contract for before and after hooks
/// @dev This contract is inherited by handlers
abstract contract DefaultBeforeAfterHooks is BaseHooks {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         STRUCTS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    struct User {
        uint256 balance;
    }

    struct MarketData {
        uint256 nextCapTime;
        uint256 cap;
        uint256 removableAt;
        bool enabled;
    }

    struct DefaultVars {
        // Times
        uint256 nextGuardianUpdateTime;
        uint256 nextTimelockDecreaseTime;
        // Markets
        mapping(IERC4626 => MarketData) markets;
        // Addresses
        address guardian;
        // Assets
        uint256 totalSupply;
        uint256 totalAssets;
        uint256 lastTotalAssets;
        uint256 yield;
        // Fees
        uint256 fee;
        uint256 feeRecipientBalance;
        // Holder
        mapping(address => User) users;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       HOOKS STORAGE                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    DefaultVars defaultVarsBefore;
    DefaultVars defaultVarsAfter;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           SETUP                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Default hooks setup
    function _setUpDefaultHooks() internal {}

    /// @notice Helper to initialize storage arrays of default vars
    function _setUpDefaultVars(DefaultVars storage _dafaultVars) internal {}

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HOOKS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _defaultHooksBefore() internal {
        // Default values
        _setDefaultValues(defaultVarsBefore);
        // Health & user account data
        _setUserValues(defaultVarsBefore);
    }

    function _defaultHooksAfter() internal {
        // Default values
        _setDefaultValues(defaultVarsAfter);
        // Health & user account data
        _setUserValues(defaultVarsAfter);
    }

    /*/////////////////////////////////////////////////////////////////////////////////////////////
    //                                       HELPERS                                             //
    /////////////////////////////////////////////////////////////////////////////////////////////*/

    function _setDefaultValues(DefaultVars storage _defaultVars) internal {
        // Times
        _defaultVars.nextGuardianUpdateTime = vault.pendingGuardian().validAt;
        _defaultVars.nextTimelockDecreaseTime = vault.pendingTimelock().validAt;

        // Markets
        for (uint256 i; i < markets.length; i++) {
            IERC4626 market = markets[i];
            _defaultVars.markets[market] = MarketData({
                nextCapTime: vault.pendingCap(market).validAt,
                cap: vault.pendingCap(market).validAt,
                removableAt: vault.config(market).removableAt,
                enabled: vault.config(market).enabled
            });
        }

        // Asset
        _defaultVars.totalSupply = vault.totalSupply();
        _defaultVars.totalAssets = vault.totalAssets();
        _defaultVars.lastTotalAssets = vault.lastTotalAssets();
        _defaultVars.yield = _getUnAccountedYield();

        // Fees
        _defaultVars.fee = _getAccruedFee(_defaultVars.yield);
        _defaultVars.feeRecipientBalance = asset.balanceOf(vault.feeRecipient());

        // Addresses
        _defaultVars.guardian = vault.guardian();
    }

    function _setUserValues(DefaultVars storage _defaultVars) internal {
        for (uint256 i; i < actorAddresses.length; i++) {
            _defaultVars.users[actorAddresses[i]].balance = vault.balanceOf(actorAddresses[i]);
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   POST CONDITIONS: BASE                                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_GPOST_BASE_A() internal {
        assertGe(defaultVarsAfter.nextGuardianUpdateTime, defaultVarsBefore.nextGuardianUpdateTime, GPOST_BASE_A);

        if (_hasGuardianChanged()) {
            assertGt(block.timestamp, defaultVarsBefore.nextGuardianUpdateTime, GPOST_BASE_A);
        }
    }

    function assert_GPOST_BASE_B(IERC4626 market) internal {
        assertGe(
            defaultVarsAfter.markets[market].nextCapTime, defaultVarsBefore.markets[market].nextCapTime, GPOST_BASE_B
        );

        if (_hasCapIncreased(market)) {
            assertGt(block.timestamp, defaultVarsBefore.markets[market].nextCapTime, GPOST_BASE_B);
        }
    }

    function assert_GPOST_BASE_C() internal {
        assertGe(defaultVarsAfter.nextTimelockDecreaseTime, defaultVarsBefore.nextTimelockDecreaseTime, GPOST_BASE_C);

        if (_hasTimelockDecreased()) {
            assertGt(block.timestamp, defaultVarsBefore.nextTimelockDecreaseTime, GPOST_BASE_C);
        }
    }

    function assert_GPOST_BASE_D(IERC4626 market) internal {
        assertGe(
            defaultVarsAfter.markets[market].removableAt, defaultVarsBefore.markets[market].removableAt, GPOST_BASE_D
        );

        if (_hasMarketBeenRemoved(market)) {
            assertGt(block.timestamp, defaultVarsBefore.markets[market].removableAt, GPOST_BASE_D);
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   POST CONDITIONS: FEES                                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_GPOST_FEES_A() internal {
        uint256 feeRecipientBalanceDelta =
            UtilsLib.zeroFloorSub(defaultVarsAfter.feeRecipientBalance, defaultVarsBefore.feeRecipientBalance);
        if (feeRecipientBalanceDelta != 0) {
            assertEq(feeRecipientBalanceDelta, defaultVarsBefore.fee, GPOST_FEES_A);
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                 POST CONDITIONS: ACCOUNTING                               //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_GPOST_ACCOUNTING_A() internal {
        if (msg.sig != ISiloVaultHandler.withdrawVault.selector && msg.sig != ISiloVaultHandler.redeemVault.selector) {
            assertGe(defaultVarsAfter.totalAssets, defaultVarsBefore.totalAssets, GPOST_ACCOUNTING_A);
        }
    }

    function assert_GPOST_ACCOUNTING_B() internal {
        if (defaultVarsAfter.totalAssets > defaultVarsBefore.totalAssets) {
            assertTrue(
                (msg.sig == ISiloVaultHandler.depositVault.selector || msg.sig == ISiloVaultHandler.mintVault.selector)
                    || defaultVarsBefore.yield != 0 || defaultVarsAfter.yield != 0,
                GPOST_ACCOUNTING_B
            );
        }
    }

    function assert_GPOST_ACCOUNTING_C() internal {
        if (defaultVarsAfter.totalSupply > defaultVarsBefore.totalSupply) {
            assertTrue(
                (msg.sig == ISiloVaultHandler.depositVault.selector || msg.sig == ISiloVaultHandler.mintVault.selector)
                    || defaultVarsBefore.fee != 0,
                GPOST_ACCOUNTING_C
            );
        }
    }

    function assert_GPOST_ACCOUNTING_D() internal {
        if (defaultVarsAfter.totalSupply < defaultVarsBefore.totalSupply) {
            assertTrue(
                msg.sig == ISiloVaultHandler.withdrawVault.selector
                    || msg.sig == ISiloVaultHandler.redeemVault.selector,
                GPOST_ACCOUNTING_D
            );
        }
    }

    function assert_GPOST_ACCOUNTING_E() internal {
        if (_target == address(vault) || _target == address(publicAllocator)) {
            if (
                (msg.sig != IERC20Handler.approve.selector && msg.sig != IERC20Handler.transfer.selector)
                    && msg.sig != IERC20Handler.transferFrom.selector
            ) {
                //assertEq(defaultVarsAfter.lastTotalAssets, defaultVarsAfter.totalAssets, GPOST_ACCOUNTING_E); TODO: remove comment after testing
            }
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                  POST CONDITIONS: REENTRANCY                              //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_GPOST_REENTRANCY_A() internal {
        assertFalse(vault.reentrancyGuardEntered(), GPOST_REENTRANCY_A);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          HELPERS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _hasGuardianChanged() internal returns (bool) {
        return defaultVarsBefore.guardian != defaultVarsAfter.guardian;
    }

    function _hasCapIncreased(IERC4626 market) internal returns (bool) {
        return defaultVarsBefore.markets[market].cap < defaultVarsAfter.markets[market].cap;
    }

    function _hasTimelockDecreased() internal returns (bool) {
        return defaultVarsBefore.nextTimelockDecreaseTime > defaultVarsAfter.nextTimelockDecreaseTime;
    }

    function _hasMarketBeenRemoved(IERC4626 market) internal returns (bool) {
        return defaultVarsBefore.markets[market].enabled && !defaultVarsAfter.markets[market].enabled;
    }

    function _balanceHasNotChanged() internal returns (bool) {
        for (uint256 i; i < actorAddresses.length; i++) {
            if (
                defaultVarsBefore.users[actorAddresses[i]].balance != defaultVarsAfter.users[actorAddresses[i]].balance
            ) return false;
        }

        return true;
    }
}
