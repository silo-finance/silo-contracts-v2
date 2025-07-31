// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {IDynamicKinkModel} from "./IDynamicKinkModel.sol";
import {IInterestRateModel} from "./IInterestRateModel.sol";

interface IDynamicKinkModelFactory {
    event NewDynamicKinkModel(IDynamicKinkModel indexed irm);

    /// @dev verifies config and creates IRM config contract
    /// @notice it can be used in separate tx eg config can be prepared before it will be used for Silo creation
    /// @param _config IRM configuration
    /// @param _initialOwner initial owner of model
    /// @param _silo address of silo for which model is created
    /// @return irm deployed (or existing one, depends on the config) contract address
    function create(
        IDynamicKinkModel.Config calldata _config, 
        address _initialOwner,
        address _silo
    )
        external
        returns (IInterestRateModel irm);

    /// @notice Generates a default config for the DynamicKinkModel based on the provided parameters.
    /// @dev This function is used to create a config that can be used to initialize a DynamicKinkModel instance.
    /// @param _default Default configuration parameters for the DynamicKinkModel.
    /// @return config The generated configuration for the DynamicKinkModel.
    function generateDefaultConfig(IDynamicKinkModel.DefaultConfig calldata _default)
        external
        view
        returns (IDynamicKinkModel.Config memory config);

    /// @notice Check if variables in config match the limits from model whitepaper.
    /// Some limits are narrower than in whhitepaper, because of additional research, see:
    /// https://silofinance.atlassian.net/wiki/spaces/SF/pages/347963393/DynamicKink+model+config+limits+V1
    /// @dev it throws when config is invalid
    /// @param _config DynamicKinkModel config struct, does not include the state of the model.
    function verifyConfig(IDynamicKinkModel.Config calldata _config) external view;
}
