// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries
import {Pretty, Strings} from "../utils/Pretty.sol";
import "forge-std/console.sol";



// Interfaces
import {IERC4626} from "openzeppelin5/token/ERC20/extensions/ERC4626.sol";
import {IVaultHandler} from "../handlers/interfaces/IVaultHandler.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// Test Contracts
import {BaseHooks} from "../base/BaseHooks.t.sol";
import {Actor} from "../utils/Actor.sol";

/// @title Default Before After Hooks
/// @notice Helper contract for before and after hooks
/// @dev This contract is inherited by handlers
abstract contract DefaultBeforeAfterHooks is BaseHooks {
    using Strings for string;
    using Pretty for uint256;
    using Pretty for int256;
    using Pretty for bool;

    struct DefaultVars {
        // ERC4626
        uint256 totalSupply;
        uint256 exchangeRate;
        uint256 totalAssets;
        uint256 supplyCap;
        // xSilo
        uint256 balance;
        uint256 cash;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       HOOKS STORAGE                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    mapping(address => DefaultVars) defaultVarsBefore;
    mapping(address => DefaultVars) defaultVarsAfter;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           SETUP                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Default hooks setup
    function _setUpDefaultHooks() internal {}

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HOOKS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _defaultHooksBefore(address _xSilo) internal {
        _setXSiloValues(_xSilo, defaultVarsBefore[_xSilo]);
    }

    function _defaultHooksAfter(address _xSilo) internal {
        _setXSiloValues(_xSilo, defaultVarsAfter[_xSilo]);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           SETTERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _setXSiloValues(address _xSilo, DefaultVars storage _defaultVars) internal {
        _defaultVars.totalSupply = IERC4626(_xSilo).totalSupply();
        _defaultVars.totalAssets = IERC4626(_xSilo).totalAssets();
    }


    /*/////////////////////////////////////////////////////////////////////////////////////////////
    //                                  GLOBAL POST CONDITIONS                                   //
    /////////////////////////////////////////////////////////////////////////////////////////////*/
}
