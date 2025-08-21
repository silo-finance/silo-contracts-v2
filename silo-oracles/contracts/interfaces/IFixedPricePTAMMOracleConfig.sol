// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {IPendleAMM} from "./IPendleAMM.sol";

interface IFixedPricePTAMMOracleConfig {
    /// @param amm Pendle AMM contract address,
    /// see https://pendle.notion.site/Cross-chain-PT-21f567a21d3780c5b7c9fe055565d762
    /// @param ptToken PT token address
    /// @param ptUnderlyingQuoteToken quote token address, that must be underlying token of PT
    struct DeploymentConfig {
        IPendleAMM amm;
        address ptToken;
        address ptUnderlyingQuoteToken;
    }

    function getConfig() external view returns (DeploymentConfig memory cfg);
}
