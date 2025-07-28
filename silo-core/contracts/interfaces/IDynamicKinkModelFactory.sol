// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {IDynamicKinkModel} from "./IDynamicKinkModel.sol";

interface IDynamicKinkModelFactory {
    /// @dev config hash and IRM should be easily accessible directly from oracle contract
    event NewDynamicKinkModel(bytes32 indexed configHash, IDynamicKinkModel indexed irm);

    /// @notice Generates a default config for the DynamicKinkModel based on the provided parameters.
    /// @dev This function is used to create a config that can be used to initialize a DynamicKinkModel instance.
    /// @param _default Default configuration parameters for the DynamicKinkModel.
    /// @return config The generated configuration for the DynamicKinkModel.
    function generateDefaultConfig(IDynamicKinkModel.DefaultConfig calldata _default) 
        external 
        view 
        returns (IDynamicKinkModel.Config memory config);

    /// @dev verifies config and creates IRM config contract
    /// @notice it can be used in separate tx eg config can be prepared before it will be used for Silo creation
    /// @param _config IRM configuration
    /// @param _externalSalt external salt for the create2 call
    /// @return configHash the hashed config used as a key for IRM contract
    /// @return irm deployed (or existing one, depends on the config) contract address
    function create(IDynamicKinkModel.Config calldata _config, bytes32 _externalSalt)
        external
        returns (bytes32 configHash, IDynamicKinkModel irm);

    /// @dev DP in 18 decimal points used for integer calculations
    // solhint-disable-next-line func-name-mixedcase
    function DP() external view returns (uint256);

    /// @notice Check if variables in config match the limits from model whitepaper.
    /// Some limits are narrower than in whhitepaper, because of additional research, see:
    /// https://silofinance.atlassian.net/wiki/spaces/SF/pages/347963393/DynamicKink+model+config+limits+V1
    /// @dev it throws when config is invalid
    /// @param _config DynamicKinkModel config struct, does not include the state of the model.
    function verifyConfig(IDynamicKinkModel.Config calldata _config) external view;

    /// @dev hashes IRM config
    /// @param _config IRM config
    /// @return configId hash of `_config`
    function hashConfig(IDynamicKinkModel.Config calldata _config) external pure returns (bytes32 configId);
}
