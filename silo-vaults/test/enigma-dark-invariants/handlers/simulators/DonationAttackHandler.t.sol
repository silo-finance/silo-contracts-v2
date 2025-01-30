// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Libraries
import "forge-std/console.sol";

// Test Contracts
import {Actor} from "../../utils/Actor.sol";
import {TestERC20} from "../../utils/mocks/TestERC20.sol";
import {BaseHandler} from "../../base/BaseHandler.t.sol";

/// @title DonationAttackHandler
/// @notice Handler test contract for a set of actions
contract DonationAttackHandler is BaseHandler {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      STATE VARIABLES                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ACTIONS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice This function transfers any amount of underlying assets to the SiloVault contract simulating
    /// a big range of donation attacks
    function donateUnderlyingToVault(uint256 amount) external {
        TestERC20 _token = asset;

        address target = address(vault);

        _token.mint(address(this), amount);

        _token.transfer(target, amount);
    }

    /// @notice This function transfers any amount of Silos shares to the SiloVault contract simulating
    /// a big range of donation attacks
    function donateSharesToVault(uint256 amount, uint8 i) external setup {
        bool success;
        bytes memory returnData;

        TestERC20 _token = TestERC20(_getRandomMarket(i));

        address target = address(vault);

        (success, returnData) = actor.proxy(target, abi.encodeWithSelector(IERC20.transfer.selector, target, amount));
    }

    /// @notice This function transfers any amount of underlying assets the underlying silos simulating
    /// a big range of donation attacks
    function donateUnderlyingToSilo(uint256 amount, uint8 i) external {
        address target = _getRandomMarket(i);

        TestERC20 _token = asset;

        _token.mint(address(this), amount);

        _token.transfer(target, amount);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         OWNER ACTIONS                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
