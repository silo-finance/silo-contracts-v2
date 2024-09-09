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

/// @title BorrowingHandler
/// @notice Handler test contract for a set of actions
contract BorrowingHandler is BaseHandler {
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

    function borrow(uint256 _assets, uint8 i, uint8 j) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        address target = _getRandomSilo(j);

        _before();
        (success, returnData) =
            actor.proxy(target, abi.encodeWithSelector(ISilo.borrow.selector, _assets, receiver, address(actor)));

        if (success) {
            _after();
        }
    }

    function borrowSameAsset(uint256 _assets, uint8 i, uint8 j) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        address target = _getRandomSilo(j);

        _before();
        (success, returnData) =
            actor.proxy(target, abi.encodeWithSelector(ISilo.borrowSameAsset.selector, _assets, receiver, address(actor)));

        if (success) {
            _after();
        }
    }

    function borrowShares(uint256 _shares, uint8 i, uint8 j) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        address target = _getRandomSilo(j);

        _before();
        (success, returnData) =
            actor.proxy(target, abi.encodeWithSelector(ISilo.borrowShares.selector, _shares, receiver, address(actor)));

        if (success) {
            _after();
        }
    }

    function repay(uint256 _assets, uint8 i, uint8 j) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address borrower = _getRandomActor(i);

        address target = _getRandomSilo(j);

        _before();
        (success, returnData) =
            actor.proxy(target, abi.encodeWithSelector(ISilo.repay.selector, _assets, borrower));

        if (success) {
            _after();
        }
    }

    function repayShares(uint256 _shares, uint8 i, uint8 j) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address borrower = _getRandomActor(i);

        address target = _getRandomSilo(j);

        _before();
        (success, returnData) =
            actor.proxy(target, abi.encodeWithSelector(ISilo.repayShares.selector, _shares, borrower));

        if (success) {
            _after();
        }
    }

    function leverageSameAsset(uint256 _depositAssets, uint256 _borrowAssets, uint8 i, uint8 j, uint8 k) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address borrower = _getRandomActor(i);

        address target = _getRandomSilo(j);

        ISilo.CollateralType _collateralType = ISilo.CollateralType(k % 2);

        _before();
        (success, returnData) =
            actor.proxy(target, abi.encodeWithSelector(ISilo.leverageSameAsset.selector, _depositAssets, _borrowAssets, borrower, _collateralType));

        if (success) {
            _after();
        }
    }

    function switchCollateralToThisSilo(uint8 i) external setup {
        bool success;
        bytes memory returnData;

        address target = _getRandomSilo(i);

        _before();
        (success, returnData) =
            actor.proxy(target, abi.encodeWithSelector(ISilo.switchCollateralToThisSilo.selector));

        if (success) {
            _after();
        }
    }

    function transitionCollateral(uint256 _shares, uint8 i, uint8 j, uint8 k) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address owner = _getRandomActor(i);

        address target = _getRandomSilo(j);

        ISilo.CollateralType _collateralType = ISilo.CollateralType(k % 2);

        _before();
        (success, returnData) =
            actor.proxy(target, abi.encodeWithSelector(ISilo.transitionCollateral.selector, _shares, owner, _collateralType));

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
