// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces

// Libraries
import {EnumerableSet} from "openzeppelin5/utils/structs/EnumerableSet.sol";
import {TestERC20} from "../utils/mocks/TestERC20.sol";
import {Math} from "openzeppelin5/utils/math/Math.sol";

// Contracts
import {Actor} from "../utils/Actor.sol";
import {HookAggregator} from "../hooks/HookAggregator.t.sol";

/// @title BaseHandler
/// @notice Contains common logic for all handlers
/// @dev inherits all suite assertions since per action assertions are implmenteds in the handlers
contract BaseHandler is HookAggregator {
    using EnumerableSet for EnumerableSet.UintSet;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         MODIFIERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       SHARED VARAIBLES                                    //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                             HELPERS                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Helper function to randomize a uint256 seed with a string salt
    function _randomize(uint256 seed, string memory salt) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(seed, salt)));
    }

    /// @notice Helper function to get a random value
    function _getRandomValue(uint256 modulus) internal view returns (uint256) {
        uint256 randomNumber = uint256(keccak256(abi.encode(block.timestamp, block.prevrandao, msg.sender)));
        return randomNumber % modulus; // Adjust the modulus to the desired range
    }

    /// @notice Helper function to mint an amount of tokens to an address
    function _mint(address token, address receiver, uint256 amount) internal {
        TestERC20(token).mint(receiver, amount);
    }

    /// @notice Helper function to mint an amount of tokens to an address and approve them to a spender
    /// @param token Address of the token to mint
    /// @param owner Address of the new owner of the tokens
    /// @param spender Address of the spender to approve the tokens to
    /// @param amount Amount of tokens to mint and approve
    function _mintAndApprove(address token, address owner, address spender, uint256 amount) internal {
        _mint(token, owner, amount);
        _approve(token, owner, spender, amount);
    }

    function _mintApproveAndDeposit(address _vault, address owner, uint256 amount) internal {
        _mintAndApprove(address(vault.asset()), owner, _vault, amount * 2);
        vm.prank(owner);
        vault.deposit(amount, owner);
    }

    function _mintApproveAndMint(address _vault, address owner, uint256 amount) internal {
        _mintAndApprove(address(vault.asset()), owner, _vault, vault.previewMint(amount) * 2);
        vault.mint(amount, owner);
    }
}
