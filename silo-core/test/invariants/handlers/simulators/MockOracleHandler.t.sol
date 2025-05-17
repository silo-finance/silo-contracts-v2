// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// Libraries
import "forge-std/console.sol";

// Test Contracts
import {Actor} from "../../utils/Actor.sol";
import {BaseHandler} from "../../base/BaseHandler.t.sol";
import {MockSiloOracle} from "../../utils/mocks/MockSiloOracle.sol";

/// @title MockOracleHandler
/// @notice Handler test contract for a set of actions
contract MockOracleHandler is BaseHandler {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         CONSTANTS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    uint256 public constant MIN_PRICE = 1e10;
    uint256 public constant MAX_PRICE = 1e26;

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

    function setOraclePrice(uint256 _price, uint8 i) external setup {
        bool success;
        bytes memory returnData;

        _price = clampBetween(_price, MIN_PRICE, MAX_PRICE);

        // Get one of the mock oracles randomly
        address target = _getRandomOracle(i);

        MockSiloOracle(target).setPrice(_price);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         OWNER ACTIONS                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
