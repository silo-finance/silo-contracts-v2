// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {IFixedPricePTAMMOracleConfig} from "./IFixedPricePTAMMOracleConfig.sol";
import {IFixedPricePTAMMOracle} from "./IFixedPricePTAMMOracle.sol";

interface IFixedPricePTAMMOracleFactory {
    error DeployerCannotBeZero();
    error AddressZero();
    error TokensAreTheSame();

    function create(IFixedPricePTAMMOracleConfig.DeploymentConfig memory _config, bytes32 _externalSalt)
        external
        returns (IFixedPricePTAMMOracle oracle);

    function resolveExistingOracle(bytes32 _configId) external view returns (address oracle);

    function hashConfig(IFixedPricePTAMMOracleConfig.DeploymentConfig memory _config) 
        external 
        view 
        returns (bytes32 configId);

    function verifyConfig(IFixedPricePTAMMOracleConfig.DeploymentConfig memory _config) external view;
}
