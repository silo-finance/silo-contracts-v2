// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// Libraries
import "forge-std/console.sol";

// Test Contracts
import {Actor} from "../../utils/Actor.sol";
import {BaseHandler} from "../../base/BaseHandler.t.sol";

/// @title SiloFactoryHandler
/// @notice Handler test contract for a set of actions
contract SiloFactoryHandler is BaseHandler {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      STATE VARIABLES                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ACTIONS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function setDaoFee(uint128 _minFee, uint128 _maxFee) external {
        siloFactory.setDaoFee(_minFee, _maxFee);
    }

    function setMaxDeployerFee(uint256 _newMaxDeployerFee) internal {
        siloFactory.setMaxDeployerFee(_newMaxDeployerFee);
    }

    function setMaxFlashloanFee(uint256 _newMaxFlashloanFee) internal {
        siloFactory.setMaxFlashloanFee(_newMaxFlashloanFee);
    }

    function setMaxLiquidationFee(uint256 _newMaxLiquidationFee) internal {
        siloFactory.setMaxLiquidationFee(_newMaxLiquidationFee);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         OWNER ACTIONS                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
