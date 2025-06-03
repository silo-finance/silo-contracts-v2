// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC4626} from "openzeppelin5/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

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

    function deposit(uint256 _assets, uint8 i) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        _before();

        (success, returnData) =
            actor.proxy(address(xSilo), abi.encodeWithSelector(IERC4626.deposit.selector, _assets, receiver));

        // POST-CONDITIONS

        if (success) {
            _after();

            assertApproxEqAbs(
                defaultVarsBefore[xSilo].totalAssets + _assets,
                defaultVarsAfter[xSilo].totalAssets,
                1,
                LENDING_HSPOST_A
            );
        }

        if (_assets == 0) {
            assertFalse(success, SILO_HSPOST_B);
        }
    }

    function mint(uint256 _shares, uint8 i) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        _before();

        (success, returnData) =
            actor.proxy(address(xSilo), abi.encodeWithSelector(IERC4626.mint.selector, _shares, receiver));

        // POST-CONDITIONS

        if (success) {
            _after();

            assertEq(
                defaultVarsBefore[xSilo].totalSupply + _shares,
                defaultVarsAfter[xSilo].totalSupply,
                LENDING_HSPOST_A
            );
        }

        if (_shares == 0) {
            assertFalse(success, SILO_HSPOST_B);
        }
    }

    function withdraw(uint256 _assets, uint8 i) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        _before();

        (success, returnData) = actor.proxy(
            address(xSilo), abi.encodeWithSelector(IERC4626.withdraw.selector, _assets, receiver, address(actor))
        );

        // POST-CONDITIONS

        if (success) {
            _after();
        }

        if (_assets == 0) {
            assertFalse(success, SILO_HSPOST_B);
        }
    }

    function redeem(uint256 _shares, uint8 i) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        _before();

        (success, returnData) = actor.proxy(
            address(xSilo), abi.encodeWithSelector(IERC4626.redeem.selector, _shares, receiver, address(actor))
        );

        if (success) {
            _after();
        }

        // POST-CONDITIONS
        if (_shares == 0) {
            assertFalse(success, SILO_HSPOST_B);
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          PROPERTIES                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_LENDING_INVARIANT_B() public setup {
        bool success;
        bytes memory returnData;

        uint256 maxWithdraw = xSilo.maxWithdraw(address(actor));

        _before();

        (success, returnData) = actor.proxy(
            address(xSilo),
            abi.encodeWithSelector(
                IERC4626.withdraw.selector, maxWithdraw, address(actor), address(actor)
            )
        );

        if (success) {
            _after();
        }

        // POST-CONDITIONS

        if (maxWithdraw != 0) {
            assertTrue(success, LENDING_INVARIANT_B);
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         OWNER ACTIONS                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
