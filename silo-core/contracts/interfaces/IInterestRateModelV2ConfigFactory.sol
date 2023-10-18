// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {IInterestRateModelV2} from "./IInterestRateModelV2.sol";
import {IInterestRateModelV2Config} from "./IInterestRateModelV2Config.sol";

interface IInterestRateModelV2ConfigFactory {
    /// @dev config ID and config address should be easily accessible directly from oracle contract
    event NewInterestRateModelV2Config(bytes32 indexed id, IInterestRateModelV2Config indexed configAddress);

    /// @dev verifies config and creates IRM config contract
    /// @notice it can be used in separate tx eg config can be prepared before it will be used for Silo creation
    /// @param _config IRM configuration
    /// @return id unique ID of the config
    /// @return configContract deployed (or existing one, depends on ID) contract address
    function create(IInterestRateModelV2.Config calldata _config)
        external
        returns (bytes32 id, IInterestRateModelV2Config configContract);

    /// @dev DP is 18 decimal points used for integer calculations
    // solhint-disable-next-line func-name-mixedcase
    function DP() external view returns (uint256);
    function verifyConfig(IInterestRateModelV2.Config calldata _config) external view;
    function hashConfig(IInterestRateModelV2.Config calldata _config) external pure returns (bytes32 configId);
}
