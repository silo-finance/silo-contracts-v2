// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface IFixedPricePTAMMOracleConfig {
    struct DeploymentConfig {
        IPendleAMM amm;
        address baseToken;
        address quoteToken;
    }

    function getConfig() external view returns (DeploymentConfig memory cfg);
}
