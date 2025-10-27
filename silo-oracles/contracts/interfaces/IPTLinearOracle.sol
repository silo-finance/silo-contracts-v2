// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {AggregatorV3Interface} from "chainlink/v0.8/interfaces/AggregatorV3Interface.sol";

import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {IPTLinearOracleConfig} from "./IPTLinearOracleConfig.sol";

interface IPTLinearOracle is ISiloOracle, AggregatorV3Interface {
    event PTLinearOracleInitialized(IPTLinearOracleConfig indexed configAddress);

    error NotInitialized();
    error EmptyConfigAddress();
    error AssetNotSupported();
    error ZeroQuote();
    error BaseAmountOverflow();

    /// @notice validation of config is checked in factory, therefore you should not deploy and initialize directly
    /// use factory always.
    function initialize(IPTLinearOracleConfig _configAddress) external;

    function oracleConfig() external view returns (IPTLinearOracleConfig);

    /// @dev returns the max discount per year that oracle was created with
    function baseDiscountPerYear() external view returns (uint256);
}
