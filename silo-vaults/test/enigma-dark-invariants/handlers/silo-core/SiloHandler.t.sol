// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

// Libraries
import "forge-std/console.sol";

// Test Contracts
import {Actor} from "../../utils/Actor.sol";
import {BaseHandler} from "../../base/BaseHandler.t.sol";

/// @title SiloHandler
/// @notice Handler test contract for a set of actions
abstract contract SiloHandler is BaseHandler {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      STATE VARIABLES                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                    ACTIONS: BORROWING                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function borrow(uint256 _assets, uint8 i, uint8 j) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        address target = _getRandomLoanMarketAddress(j);

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

        address target = _getRandomSiloAddress(j);

        _before();
        (success, returnData) = actor.proxy(
            target, abi.encodeWithSelector(ISilo.borrowSameAsset.selector, _assets, receiver, address(actor))
        );

        if (success) {
            _after();
        }
    }

    function repay(uint256 _assets, uint8 i, uint8 j) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address borrower = _getRandomActor(i);

        address target = _getRandomSiloAddress(j);

        _before();
        (success, returnData) = actor.proxy(target, abi.encodeWithSelector(ISilo.repay.selector, _assets, borrower));

        if (success) {
            _after();
        }
    }

    function switchCollateralToThisSilo(uint8 i) external setup {
        bool success;
        bytes memory returnData;

        address target = _getRandomSiloAddress(i);

        _before();
        (success, returnData) = actor.proxy(target, abi.encodeWithSelector(ISilo.switchCollateralToThisSilo.selector));

        if (success) {
            _after();
        }
    }

    function transitionCollateral(uint256 _shares, uint8 i, uint8 j, uint8 k) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address owner = _getRandomActor(i);

        address target = _getRandomSiloAddress(j);

        ISilo.CollateralType _collateralType = ISilo.CollateralType(k % 2);

        _before();
        (success, returnData) = actor.proxy(
            target, abi.encodeWithSelector(ISilo.transitionCollateral.selector, _shares, owner, _collateralType)
        );

        if (success) {
            _after();
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                        ACTIONS: MISC                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function accrueInterest(uint8 i) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address target = _getRandomSiloAddress(i);

        _before();
        (success, returnData) = actor.proxy(target, abi.encodeWithSelector(ISilo.accrueInterest.selector));

        if (success) {
            _after();
        }
    }

    function withdrawFees(uint8 i) external {
        address target = _getRandomSiloAddress(i);

        _before();
        ISilo(target).withdrawFees();

        _after();
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
