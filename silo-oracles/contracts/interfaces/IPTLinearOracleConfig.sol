// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface IPTLinearOracleConfig {
    struct OracleConfig {
        address linearOracle;
        address ptToken;
        address syToken;
        address expectedUnderlyingToken;
        address hardcodedQuoteToken;
        bytes4 syRateMethodSelector;
    }

    error LinearOracleCannotBeZero();

    function getConfig() external view returns (OracleConfig memory cfg);
}
