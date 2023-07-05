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
}
