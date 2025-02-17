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

            // POSTCONDITIONS

            /// @dev ERC4626_DEPOSIT_INVARIANT_B
            assertLe(previewedShares, shares, ERC4626_DEPOSIT_INVARIANT_B);

            /// @dev HSPOST_USER_E
            assertEq(
                defaultVarsBefore.users[receiver].balance + shares,
                defaultVarsAfter.users[receiver].balance,
                HSPOST_USER_E
            );

            /* assertEq(// TODO remove comment once test_replay_2depositVault is checked
                defaultVarsBefore.lastTotalAssets + _assets + defaultVarsBefore.yield,
                defaultVarsAfter.lastTotalAssets,
                HSPOST_ACCOUNTING_C
            ); */

            /// @dev HSPOST_USER_C
            //assertEq(defaultVarsBefore.totalAssets + _assets, defaultVarsAfter.totalAssets, HSPOST_USER_C);// TODO remove comment once test_replay_depositVault is checked
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

            // POSTCONDITIONS

            uint256 assets = abi.decode(returnData, (uint256));

            /// @dev ERC4626_MINT_INVARIANT_B
            assertGe(previewedAssets, assets, ERC4626_MINT_INVARIANT_B);

            /// @dev HSPOST_USER_E
            assertEq(
                defaultVarsBefore.users[receiver].balance + _shares,
                defaultVarsAfter.users[receiver].balance,
                HSPOST_USER_E
            );

            /* assertEq(// TODO remove comment once test_replay_2mintVault is checked
                defaultVarsBefore.lastTotalAssets + assets + defaultVarsBefore.yield,
                defaultVarsAfter.lastTotalAssets,
                HSPOST_ACCOUNTING_C
            ); */

            /// @dev HSPOST_USER_C
            //assertEq(defaultVarsBefore.totalAssets + assets, defaultVarsAfter.totalAssets, HSPOST_USER_C);// TODO remove comment once test_replay_mintVault is checked
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

            uint256 shares = abi.decode(returnData, (uint256));

            // POSTCONDITIONS

            /// @dev ERC4626_WITHDRAW_INVARIANT_B
            assertGe(previewedShares, shares, ERC4626_WITHDRAW_INVARIANT_B);

            /// @dev HSPOST_USER_F
            assertEq(
                defaultVarsBefore.users[address(actor)].balance - shares,
                defaultVarsAfter.users[address(actor)].balance,
                HSPOST_USER_F
            );

            assertGe(defaultVarsBefore.totalAssets - _assets, defaultVarsAfter.totalAssets, HSPOST_ACCOUNTING_B);

            console.log("defaultVarsBefore.lastTotalAssets: ", defaultVarsBefore.lastTotalAssets);
            console.log("defaultVarsBefore.yield: ", defaultVarsBefore.yield);
            console.log("defaultVarsBefore.totalAssets: ", defaultVarsBefore.totalAssets);
            console.log("defaultVarsAfter.totalAssets: ", defaultVarsAfter.totalAssets);

            assertEq(
                defaultVarsBefore.lastTotalAssets + defaultVarsBefore.yield - _assets,
                defaultVarsAfter.lastTotalAssets,
                HSPOST_ACCOUNTING_D
            );

            /// @dev HSPOST_USER_D
            //assertEq(defaultVarsBefore.totalAssets - _assets, defaultVarsAfter.totalAssets, HSPOST_USER_D);// TODO remove comment once test_replay_withdrawVault is checked
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

            uint256 assets = abi.decode(returnData, (uint256));

            // POSTCONDITIONS

            /// @dev ERC4626_REDEEM_INVARIANT_B
            assertLe(previewedAssets, assets, ERC4626_REDEEM_INVARIANT_B);

            /// @dev HSPOST_USER_F
            assertEq(
                defaultVarsBefore.users[address(actor)].balance - _shares,
                defaultVarsAfter.users[address(actor)].balance,
                HSPOST_USER_F
            );

            assertEq(
                defaultVarsBefore.lastTotalAssets + defaultVarsBefore.yield - assets,
                defaultVarsAfter.lastTotalAssets,
                HSPOST_ACCOUNTING_D
            );

            assertGe(defaultVarsBefore.totalAssets - assets, defaultVarsAfter.totalAssets, HSPOST_ACCOUNTING_B);

            /// @dev HSPOST_USER_D
            //assertEq(defaultVarsBefore.totalAssets - assets, defaultVarsAfter.totalAssets, HSPOST_USER_D); // TODO remove comment once test_replay_redeemVault is checked
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
