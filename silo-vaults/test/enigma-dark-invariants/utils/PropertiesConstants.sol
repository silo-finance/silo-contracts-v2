// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

abstract contract PropertiesConstants {
    // Constant echidna addresses
    address constant USER1 = address(0x10000);
    address constant USER2 = address(0x20000);
    address constant USER3 = address(0x30000);
    uint256 constant INITIAL_BALANCE = 1000e30;
    uint184 constant MAX_UNDERLYING_SUPPLY = type(uint128).max;

    // Protocol constants
    int256 constant BLOCK_TIME = 1;
    uint256 constant MIN_TEST_ASSETS = 1e8;
    uint256 constant MAX_TEST_ASSETS = 1e28;
    uint184 constant CAP = type(uint128).max;
    uint256 constant NB_MARKETS = 3;
    uint256 constant TIMELOCK = 1 weeks;
    uint256 constant MAX_FEE = 0.5e18;
    /// @dev The maximum delay of a timelock.
    uint256 internal constant MAX_TIMELOCK = 2 weeks;

    /// @dev The minimum delay of a timelock.
    uint256 internal constant MIN_TIMELOCK = 1 days;

    // Suite constants
    uint256 constant NUM_MARKETS = 3;
    uint256 constant WAD = 1e18;
}
