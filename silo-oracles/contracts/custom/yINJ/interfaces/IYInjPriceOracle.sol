// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title YInjPriceOracle interface.
interface IYInjPriceOracle {
    function getExchangeRate() external view returns (uint256);
}
