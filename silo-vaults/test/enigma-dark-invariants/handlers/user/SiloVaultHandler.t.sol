// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC4626, IERC20} from "openzeppelin5/interfaces/IERC4626.sol";

// Libraries
import "forge-std/console.sol";

// Test Contracts
import {Actor} from "../../utils/Actor.sol";
import {BaseHandler} from "../../base/BaseHandler.t.sol";

/// @title SiloVaultHandler
/// @notice Handler test contract for a set of actions
abstract contract SiloVaultHandler is BaseHandler {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      STATE VARIABLES                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ACTIONS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function depositVault(uint256 _assets, uint8 i) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        address target = address(vault);

        uint256 previewedShares = vault.previewDeposit(_assets);

        _before();
        (success, returnData) =
            actor.proxy(target, abi.encodeWithSelector(IERC4626.deposit.selector, _assets, receiver));

        if (success) {
            _after();

            uint256 shares = abi.decode(returnData, (uint256));

            ///////////////////////////////////////////////////////////////////////////////////////
            //                                        HSPOST                                     //
            ///////////////////////////////////////////////////////////////////////////////////////

            /// @dev ERC4626
            assertLe(previewedShares, shares, ERC4626_DEPOSIT_INVARIANT_B);

            /// @dev USER
            assertEq(
                defaultVarsBefore.users[receiver].balance + shares,
                defaultVarsAfter.users[receiver].balance,
                HSPOST_USER_E
            );

            /// @dev ACCOUNTING
            //assertEq(defaultVarsBefore.totalAssets + _assets, defaultVarsAfter.totalAssets, HSPOST_ACCOUNTING_C);// TODO remove comment once test_replay_depositVault is checked
        } else {
            revert("SiloVaultHandler: deposit failed");
        }
    }

    function mintVault(uint256 _shares, uint8 i) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        address target = address(vault);

        uint256 previewedAssets = vault.previewMint(_shares);

        _before();
        (success, returnData) = actor.proxy(target, abi.encodeWithSelector(IERC4626.mint.selector, _shares, receiver));

        if (success) {
            _after();

            uint256 _assets = abi.decode(returnData, (uint256));

            ///////////////////////////////////////////////////////////////////////////////////////
            //                                        HSPOST                                     //
            ///////////////////////////////////////////////////////////////////////////////////////

            /// @dev ERC4626
            assertGe(previewedAssets, _assets, ERC4626_MINT_INVARIANT_B);

            /// @dev USER
            assertEq(
                defaultVarsBefore.users[receiver].balance + _shares,
                defaultVarsAfter.users[receiver].balance,
                HSPOST_USER_E
            );

            /// @dev ACCOUNTING
            //assertEq(defaultVarsBefore.totalAssets + _assets, defaultVarsAfter.totalAssets, HSPOST_ACCOUNTING_C);// TODO remove comment once test_replay_mintVault is checked
        } else {
            revert("SiloVaultHandler: mint failed");
        }
    }

    function withdrawVault(uint256 _assets, uint8 i) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        address target = address(vault);

        uint256 previewedShares = vault.previewWithdraw(_assets);

        _before();
        (success, returnData) =
            actor.proxy(target, abi.encodeWithSelector(IERC4626.withdraw.selector, _assets, receiver, address(actor)));

        if (success) {
            _after();

            uint256 _shares = abi.decode(returnData, (uint256));

            ///////////////////////////////////////////////////////////////////////////////////////
            //                                        HSPOST                                     //
            ///////////////////////////////////////////////////////////////////////////////////////

            /// @dev ERC4626
            assertGe(previewedShares, _shares, ERC4626_WITHDRAW_INVARIANT_B);

            /// @dev USER
            assertEq(
                defaultVarsBefore.users[address(actor)].balance - _shares,
                defaultVarsAfter.users[address(actor)].balance,
                HSPOST_USER_F
            );

            /// @dev ACCOUNTING
            assertGe(defaultVarsBefore.totalAssets - _assets, defaultVarsAfter.totalAssets, HSPOST_ACCOUNTING_B);

            //assertEq(defaultVarsBefore.totalAssets - _assets, defaultVarsAfter.totalAssets, HSPOST_ACCOUNTING_D);// TODO remove comment once test_replay_withdrawVault is checked
        } else {
            revert("SiloVaultHandler: withdraw failed");
        }
    }

    function redeemVault(uint256 _shares, uint8 i) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        address target = address(vault);

        uint256 previewedAssets = vault.previewRedeem(_shares);

        _before();
        (success, returnData) =
            actor.proxy(target, abi.encodeWithSelector(IERC4626.redeem.selector, _shares, receiver, address(actor)));

        if (success) {
            _after();

            uint256 _assets = abi.decode(returnData, (uint256));

            ///////////////////////////////////////////////////////////////////////////////////////
            //                                        HSPOST                                     //
            ///////////////////////////////////////////////////////////////////////////////////////

            /// @dev ERC4626
            assertLe(previewedAssets, _assets, ERC4626_REDEEM_INVARIANT_B);

            /// @dev USER
            assertEq(
                defaultVarsBefore.users[address(actor)].balance - _shares,
                defaultVarsAfter.users[address(actor)].balance,
                HSPOST_USER_F
            );

            /// @dev ACCOUNTING
            assertGe(defaultVarsBefore.totalAssets - _assets, defaultVarsAfter.totalAssets, HSPOST_ACCOUNTING_B);
            //assertEq(defaultVarsBefore.totalAssets - assets, defaultVarsAfter.totalAssets, HSPOST_ACCOUNTING_D); // TODO remove comment once test_replay_redeemVault is checked
        } else {
            revert("SiloVaultHandler: redeem failed");
        }
    }

    function skim(uint8 i) external {
        vault.skim(_getRandomSuiteAsset(i));
    }

    function claimRewards() external {
        vault.claimRewards();
    }
}
