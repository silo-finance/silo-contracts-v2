// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface IPTLinearOracleConfig {
    struct OracleConfig {
        address linearOracle;
        address ptToken;
        address hardcodedQuoteToken;
    }

    function getConfig() external view returns (OracleConfig memory cfg);
}
