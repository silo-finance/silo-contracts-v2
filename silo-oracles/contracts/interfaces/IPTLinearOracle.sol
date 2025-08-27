// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {IPTLinearOracleConfig} from "./IPTLinearOracleConfig.sol";

interface IPTLinearOracle is ISiloOracle {
    event PTLinearOracleInitialized(IPTLinearOracleConfig indexed configAddress);

    error NotInitialized();
    error EmptyConfigAddress();
    error AssetNotSupported();
    error InvalidExchangeFactor();
    error ZeroQuote();
    error BaseAmountOverflow();
    error FailedToCallSyRateMethod();

    /// @notice validation of config is checked in factory, therefore you should not deploy and initialize directly
    /// use factory always.
    function initialize(IPTLinearOracleConfig _configAddress, string memory _syRateMethod) external;

    /// @dev resolves the exchange factor for the given syToken and syRateMethodSelector
    ///required for the PTLinearOracle to calculate the quote
    function callForExchangeFactor(address _syToken, bytes4 _syRateMethodSelector)
        external
        view
        returns (uint256 exchangeFactor);

    function oracleConfig() external view returns (IPTLinearOracleConfig);

    /// @dev returns the PT multiplier of the linear oracle, for debugging purposes
    function multiplier() external view returns (int256);

    /// @dev returns the syRateMethod of the linear oracle, for debugging purposes
    function syRateMethod() external view returns (string memory);
}
