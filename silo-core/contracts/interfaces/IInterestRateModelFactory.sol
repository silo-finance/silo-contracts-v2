// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {IInterestRateModel} from "./IInterestRateModel.sol";

/// @title generic interface for Interest Rate Model Factory
interface IInterestRateModelFactory {
    /// @dev verifies config and creates IRM config contract
    /// @notice it can be used in separate tx eg config can be prepared before it will be used for Silo creation
    /// @param _config IRM configuration
    /// @param _externalSalt external salt for the create2 call
    /// @return configHash the hashed config used as a key for IRM contract
    /// @return irm deployed (or existing one, depends on the config) contract address
    function create(bytes calldata _config, bytes32 _externalSalt)
        external
        returns (bytes32 configHash, IInterestRateModel irm);

    /// @dev DP is 18 decimal points used for integer calculations
    // solhint-disable-next-line func-name-mixedcase
    function DP() external view returns (uint256);

    /// @dev verifies if config has correct values for a model, throws on invalid `_config`
    /// @param _config config that will ve verified
    function verifyConfig(bytes calldata _config) external view;

    /// @dev hashes IRM config
    /// @param _config IRM config
    /// @return configId hash of `_config`
    function hashConfig(bytes calldata _config) external pure returns (bytes32 configId);
}
