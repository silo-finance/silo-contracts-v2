// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {AggregatorV3Interface} from "chainlink/v0.8/interfaces/AggregatorV3Interface.sol";

interface IPythAggregatorFactory {
    /// @dev Get Pyth address, which is used for aggregators deployment.
    function pyth() external view returns (address);

    /// @notice Get deployed aggregator address for a specific price id.
    /// @param _priceId Pyth feed price id.
    /// @return aggregator PythAggregatorV3 address deployed by this factory.
    function aggregators(bytes32 _priceId) external view returns (AggregatorV3Interface);

    /// @notice Deploy aggregator for a specific price id. Reverts if the aggregator is already deployed. This function
    /// is permissionless.
    /// @param _priceId Pyth feed price id.
    /// @param _externalSalt The external salt to be used together with factory salt
    /// @return aggregator PythAggregatorV3 address deployed by this function call.
    function deploy(
        bytes32 _priceId,
        bytes32 _externalSalt
    ) external returns (AggregatorV3Interface);

    /// @dev Emitted when the aggregator is deployed.
    /// @param priceId Pyth feed price id.
    /// @param aggregator New aggregator address.
    event AggregatorDeployed(bytes32 indexed priceId, AggregatorV3Interface indexed aggregator);

    /// @dev Revert if the aggregator is already deployed for price id.
    error AggregatorAlreadyExists();
}
