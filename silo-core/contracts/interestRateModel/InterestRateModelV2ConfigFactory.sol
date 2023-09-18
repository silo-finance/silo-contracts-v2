// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {IInterestRateModel} from "../interfaces/IInterestRateModel.sol";
import {IInterestRateModelV2} from "../interfaces/IInterestRateModelV2.sol";
import {InterestRateModelV2Config} from "./InterestRateModelV2Config.sol";

/// @title InterestRateModelV2ConfigFactory
/// @dev It creates InterestRateModelV2Config.
contract InterestRateModelV2ConfigFactory {
    /// @dev DP is 18 decimal points used for integer calculations
    uint256 public constant DP = 1e18;

    /// @dev hash(config) => config contract
    /// config ID is determine by initial configuration, the logic is the same, so config is the only difference
    /// that's why we can use it as ID, at the same time we can detect duplicated and save gas by reusing same config
    /// multiple times
    mapping(bytes32 => InterestRateModelV2Config) public getConfigAddress;

    /// @dev config ID and config address should be easily accessible directly from oracle contract
    event NewInterestRateModelV2Config(bytes32 indexed id, InterestRateModelV2Config indexed configAddress);

    /// @dev verifies config and creates IRM config contract
    /// @notice it can be used in separate tx eg config can be prepared before it will be used for Silo creation
    /// @param _config IRM configuration
    /// @return id unique ID of the config
    /// @return configContract deployed (or existing one, depends on ID) contract address
    function create(IInterestRateModelV2.Config calldata _config)
        external
        virtual
        returns (bytes32 id, InterestRateModelV2Config configContract)
    {
        id = hashConfig(_config);

        configContract = getConfigAddress[id];

        if (address(configContract) != address(0)) {
            return (id, configContract);
        }

        verifyConfig(_config);
        configContract = new InterestRateModelV2Config(_config);
        getConfigAddress[id] = configContract;

        emit NewInterestRateModelV2Config(id, configContract);
    }

    /// @dev set config for silo and asset
    function verifyConfig(IInterestRateModelV2.Config calldata _config) public view virtual {
    // solhint-disable-previous-line code-complexity
        int256 dp = int256(DP);

        if (_config.uopt <= 0 || _config.uopt >= dp) revert IInterestRateModelV2.InvalidUopt();
        if (_config.ucrit <= _config.uopt || _config.ucrit >= dp) revert IInterestRateModelV2.InvalidUcrit();
        if (_config.ulow <= 0 || _config.ulow >= _config.uopt) revert IInterestRateModelV2.InvalidUlow();
        if (_config.ki < 0) revert IInterestRateModelV2.InvalidKi();
        if (_config.kcrit < 0) revert IInterestRateModelV2.InvalidKcrit();
        if (_config.klow < 0) revert IInterestRateModelV2.InvalidKlow();
        if (_config.klin < 0) revert IInterestRateModelV2.InvalidKlin();
        if (_config.beta < 0) revert IInterestRateModelV2.InvalidBeta();
    }

    function hashConfig(IInterestRateModelV2.Config calldata _config)
        public
        pure
        virtual
        returns (bytes32 configId)
    {
        configId = keccak256(abi.encode(_config));
    }
}
