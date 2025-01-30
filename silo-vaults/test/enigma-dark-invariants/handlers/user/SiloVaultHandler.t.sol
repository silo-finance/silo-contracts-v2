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

        _before();
        (success, returnData) =
            actor.proxy(target, abi.encodeWithSelector(IERC4626.deposit.selector, _assets, receiver));

        if (success) {
            _after();
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

        _before();
        (success, returnData) = actor.proxy(target, abi.encodeWithSelector(IERC4626.mint.selector, _shares, receiver));

        if (success) {
            _after();
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

        _before();
        (success, returnData) =
            actor.proxy(target, abi.encodeWithSelector(IERC4626.withdraw.selector, _assets, receiver, address(actor)));

        if (success) {
            _after();
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

        _before();
        (success, returnData) =
            actor.proxy(target, abi.encodeWithSelector(IERC4626.redeem.selector, _shares, receiver, address(actor)));

        if (success) {
            _after();
        } else {
            revert("SiloVaultHandler: redeem failed");
        }
    }

    function skim() external {// TODO coverage
        vault.skim(address(asset)); // TODO add markets erc20 as well
    }

    function claimRewards() external {
        vault.claimRewards();
    }
}
