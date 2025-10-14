// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface IPTLinearOracleConfig {
    /// @param linearOracle Linear oracle address deploybed by ISparkLinearDiscountOracleFactory
    /// @param ptToken PT token address
    /// @param hardcodedQuoteToken Hardcoded quote token address that will be used for quoteToken() function in oracle
    /// @param normalizationDivider Normalization divider, must be 10 ** tokenDecimals of ptToken
    struct OracleConfig {
        address linearOracle;
        address ptToken;
        address hardcodedQuoteToken;
        uint256 normalizationDivider;
    }

    function getConfig() external view returns (OracleConfig memory cfg);
}
