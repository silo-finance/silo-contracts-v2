// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {IPTLinearOracleConfig} from "./IPTLinearOracleConfig.sol";
import {IPTLinearOracle} from "./IPTLinearOracle.sol";

/// @dev This interface is used to create and verify PTLinearOracle.
/// @notice PT markets are not deterministic, so there is no guarantee that this code will work for all markets.
interface IPTLinearOracleFactory {
    /// @param ptToken Pendle PT token address, for which oracle will be created
    /// @param maxYield Maximum liquidity yeald, this should be manually read from market specyfication,
    /// Yield range is provided in pendle UI eg for 4% - 25% range we should use 0.25e18, 1e18 is 100%.
    /// @param hardcodedQuoteToken This address will be used as quote token in oracle
    struct DeploymentConfig {
        address ptToken;
        uint256 maxYield;
        address hardcodedQuoteToken;
    }

    error DeployerCannotBeZero();
    error AddressZero();
    error InvalidMaxYield();
    error MaturityDateIsInThePast();
    error MaturityDateInvalid();
    error LinearOracleCannotBeZero();

    function create(DeploymentConfig memory _config, bytes32 _externalSalt)
        external
        returns (IPTLinearOracle oracle);

    function resolveExistingOracle(bytes32 _configId) external view returns (address oracle);

    function hashConfig(DeploymentConfig memory _deploymentConfig) external view returns (bytes32 configId);

    function createAndVerifyOracleConfig(DeploymentConfig memory _deploymentConfig)
        external
        returns (IPTLinearOracleConfig.OracleConfig memory oracleConfig);

    function predictAddress(DeploymentConfig memory _deploymentConfig, address _deployer, bytes32 _externalSalt)
        external
        view
        returns (address predictedAddress);
}
