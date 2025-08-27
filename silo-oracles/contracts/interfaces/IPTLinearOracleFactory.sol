// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {IPTLinearOracleConfig} from "./IPTLinearOracleConfig.sol";
import {IPTLinearOracle} from "./IPTLinearOracle.sol";

/// @dev This interface is used to create and verify PTLinearOracle.
/// @notice PT markets are not deterministic, so there is no guarantee that this code will work for all markets.
interface IPTLinearOracleFactory {
    /// @param ptMarket Pendle Market address, necessary data will be pulled from this market
    /// @param expectedUnderlyingToken token address that must match Silo's underlying token
    /// @param maxYield Maximum liquidity yeald, this should be manually read from market specyfication,
    /// Yield range is provided in pendle UI eg for 4% - 25% range we should use 0.25e18, 1e18 is 100%.
    /// @param hardcodedQuoteToken This address will be used as quote token in oracle
    /// @param syRateMethod SY rate method name eg "exchangeRate()" that will be used to pull exchange factor
    struct DeploymentConfig {
        address ptMarket;
        address expectedUnderlyingToken;
        uint256 maxYield;
        address hardcodedQuoteToken;
        string syRateMethod;
    }

    error DeployerCannotBeZero();
    error AddressZero();
    error InvalidMaxYield();
    error InvalidSyRateMethod();
    error PTTokenDoesNotMatchMarket();
    error FailedToCallSyRateMethod();
    error AssetAddressMustBeOurUnderlyingToken();
    error InvalidExchangeFactor();
    error MaturityDateIsInThePast();

    function create(DeploymentConfig memory _config, bytes32 _externalSalt)
        external
        returns (IPTLinearOracle oracle);

    function resolveExistingOracle(bytes32 _configId) external view returns (address oracle);

    function hashConfig(IPTLinearOracleConfig.OracleConfig memory _config) external view returns (bytes32 configId);

    function createAndVerifyConfig(DeploymentConfig memory _config)
        external
        view
        returns (IPTLinearOracleConfig.OracleConfig memory oracleConfig);

    function predictAddress(DeploymentConfig memory _config, address _deployer, bytes32 _externalSalt)
        external
        view
        returns (address predictedAddress);
}
