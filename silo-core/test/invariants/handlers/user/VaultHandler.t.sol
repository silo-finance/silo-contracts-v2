// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {ISilo} from "silo-core/contracts/Silo.sol";

// Libraries
import "forge-std/console.sol";

// Test Contracts
import {Actor} from "../../utils/Actor.sol";
import {BaseHandler} from "../../base/BaseHandler.t.sol";

/// @title VaultHandler
/// @notice Handler test contract for a set of actions
contract VaultHandler is BaseHandler {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      STATE VARIABLES                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ACTIONS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function deposit(uint256 _assets, uint8 i, uint8 j, uint8 k) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        address target = _getRandomSilo(j);

        ISilo.CollateralType _collateralType = ISilo.CollateralType(k % 2);

        _before();
        (success, returnData) = actor.proxy(target, abi.encodeWithSelector(ISilo.deposit.selector, _assets, receiver, _collateralType));

        if (success) {
            _after();
        }
    }

    function mint(uint256 _shares, uint8 i, uint8 j, uint8 k) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        address target = _getRandomSilo(j);

        ISilo.CollateralType _collateralType = ISilo.CollateralType(k % 2);

        _before();
        (success, returnData) = actor.proxy(target, abi.encodeWithSelector(ISilo.mint.selector, _shares, receiver, _collateralType));

        if (success) {
            _after();
        }
    }

    function withdraw(uint256 _assets, uint8 i, uint8 j, uint8 k) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        address target = _getRandomSilo(j);

        ISilo.CollateralType _collateralType = ISilo.CollateralType(k % 2);

        _before();
        (success, returnData) = actor.proxy(target, abi.encodeWithSelector(ISilo.withdraw.selector, _assets, receiver, address(actor), _collateralType));

        if (success) {
            _after();
        }
    }

    function redeem(uint256 _shares, uint8 i, uint8 j, uint8 k) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        address target = _getRandomSilo(j);

        ISilo.CollateralType _collateralType = ISilo.CollateralType(k % 2);

        _before();
        (success, returnData) = actor.proxy(target, abi.encodeWithSelector(ISilo.redeem.selector, _shares, receiver, address(actor), _collateralType));

        if (success) {
            _after();
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         OWNER ACTIONS                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
