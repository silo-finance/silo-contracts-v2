// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {IInterestRateModelV2} from "./IInterestRateModelV2.sol";
import {IInterestRateModelV2Config} from "./IInterestRateModelV2Config.sol";

interface IInterestRateModelV2ConfigFactory {
    event NewInterestRateModelV2Config(bytes32 indexed configHash, address indexed configAddress);
    event NewInterestRateModelV2(bytes32 indexed configAddress, address indexed irm);

    /// @dev verifies config and creates IRM config contract
    /// @notice it can be used in separate tx eg config can be prepared before it will be used for Silo creation
    /// @param _config IRM configuration
    /// @return configHash unique ID of the config
    /// @return irm deployed (or existing one, depends on ID) contract address
    function create(IInterestRateModelV2.Config calldata _config)
        external
        returns (bytes32 configHash, IInterestRateModelV2 irm);

    /// @dev DP is 18 decimal points used for integer calculations
    // solhint-disable-next-line func-name-mixedcase
    function DP() external view returns (uint256);

    /// @dev verifies if config has correct values for a model, throws on invalid `_config`
    /// @param _config config that will ve verified
    function verifyConfig(IInterestRateModelV2.Config calldata _config) external view;

    /// @dev hashes IRM config
    /// @param _config IRM config
    /// @return configId hash of `_config`
    function hashConfig(IInterestRateModelV2.Config calldata _config) external pure returns (bytes32 configId);
}
