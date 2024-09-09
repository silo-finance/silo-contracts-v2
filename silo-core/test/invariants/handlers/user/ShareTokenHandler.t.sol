// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// Libraries
import "forge-std/console.sol";

// Test Contracts
import {Actor} from "../../utils/Actor.sol";
import {BaseHandler} from "../../base/BaseHandler.t.sol";

/// @title ShareCollateralTokenHandler
/// @notice Handler test contract for a set of actions
contract ShareTokenHandler is BaseHandler {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      STATE VARIABLES                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /* 
    
    E.g. num of active pools
    uint256 public activePools;
        
    */

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ACTIONS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function approve(uint256 _amount, uint8 i, uint8 j) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address spender = _getRandomActor(i);

        address target = _getRandomSilo(j);

        (success, returnData) = actor.proxy(target, abi.encodeWithSelector(IERC20.approve.selector, spender, _amount));

        if (success) {
            assert(true);
        }
    }

    function transfer(uint256 _amount, uint8 i, uint8 j) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address to = _getRandomActor(i);

        address target = _getRandomSilo(j);

        (success, returnData) = actor.proxy(target, abi.encodeWithSelector(IERC20.transfer.selector, to, _amount));

        if (success) {
            assert(true);
        }
    }

    function transferFrom(uint256 _amount, uint8 i, uint8 j, uint8 k) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address from = _getRandomActor(i);
        // Get one of the three actors randomly
        address to = _getRandomActor(j);

        address target = _getRandomSilo(k);

        (success, returnData) =
            actor.proxy(target, abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, _amount));

        if (success) {
            assert(true);
        }
    }


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         OWNER ACTIONS                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    // rescueTokens

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
