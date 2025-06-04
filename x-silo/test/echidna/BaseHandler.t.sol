// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// Libraries
import {BaseHooks} from "./base/BaseHooks.t.sol";
import {TestERC20} from "./utils/mocks/TestERC20.sol";

// Contracts
import {Actor} from "./utils/Actor.sol";
import {HookAggregator} from "./hooks/HookAggregator.t.sol";

/// @title BaseHandler
/// @notice Contains common logic for all handlers
/// @dev inherits all suite assertions since per action assertions are implmenteds in the handlers
contract BaseHandler is BaseHooks {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         HELPERS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Helper function to approve an amount of tokens to a spender, a proxy Actor
    function _approve(
        address token,
        Actor actor_,
        address spender,
        uint256 amount
    ) internal {
        bool success;
        bytes memory returnData;
        (success, returnData) = actor_.proxy(
            token,
            abi.encodeWithSelector(0x095ea7b3, spender, amount)
        );
        require(success, string(returnData));
    }

    /// @notice Helper function to safely approve an amount of tokens to a spender

    function _approve(
        address token,
        address owner,
        address spender,
        uint256 amount
    ) internal {
        vm.prank(owner);
        _safeApprove(token, spender, 0);
        vm.prank(owner);
        _safeApprove(token, spender, amount);
    }

    /// @notice Helper function to safely approve an amount of tokens to a spender
    /// @dev This function is used to revert on failed approvals
    function _safeApprove(
        address token,
        address spender,
        uint256 amount
    ) internal {
        (bool success, bytes memory retdata) = token.call(
            abi.encodeWithSelector(IERC20.approve.selector, spender, amount)
        );
        assert(success);
        if (retdata.length > 0) assert(abi.decode(retdata, (bool)));
    }

    /// @notice Helper function to mint an amount of tokens to an address
    function _mint(
        address token,
        address receiver,
        uint256 amount
    ) internal {
        TestERC20(token).mint(receiver, amount);
    }

    /// @notice Helper function to mint an amount of tokens to an address and approve them to a spender
    /// @param token Address of the token to mint
    /// @param owner Address of the new owner of the tokens
    /// @param spender Address of the spender to approve the tokens to
    /// @param amount Amount of tokens to mint and approve
    function _mintAndApprove(
        address token,
        address owner,
        address spender,
        uint256 amount
    ) internal {
        _mint(token, owner, amount);
        _approve(token, owner, spender, amount);
    }
}
