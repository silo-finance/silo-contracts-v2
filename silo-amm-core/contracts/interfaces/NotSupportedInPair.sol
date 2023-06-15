// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./ISiloAmmPair.sol";

/// @dev Liquidity management is not supported in Silo AMM because it is restricted to Silos only.
/// This contact has list of all methods that are not supported but they are part of UniswapV2 router interface.
/// However it should not affect swaps in any way.
abstract contract NotSupportedInPair is ISiloAmmPair {
    function initialize(address, address) external pure {
        revert NOT_SUPPORTED();
    }

    function mint(address) external pure returns (uint) {
        revert NOT_SUPPORTED();
    }

    function burn(address) external pure returns (uint, uint){
        revert NOT_SUPPORTED();
    }

    function price0CumulativeLast() external pure returns (uint) {
        revert NOT_SUPPORTED();
    }

    function price1CumulativeLast() external pure returns (uint) {
        revert NOT_SUPPORTED();
    }

    // force balances to match reserves
    function skim(address) external pure {
        revert NOT_SUPPORTED();
    }

    // force reserves to match balances
    function sync() external pure {
        revert NOT_SUPPORTED();
    }
}
