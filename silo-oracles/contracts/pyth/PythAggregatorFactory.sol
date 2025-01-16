// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {AggregatorV3Interface} from "chainlink/v0.8/interfaces/AggregatorV3Interface.sol";
import {IPythAggregatorFactory} from "silo-oracles/contracts/interfaces/IPythAggregatorFactory.sol";
import {PythAggregatorV3} from "pyth-sdk-solidity/PythAggregatorV3.sol";

/// @notice PythAggregatorFactory is an ownable contract which forwards AggregatorV3Interface calls to the underlying
/// feed. Decimals are immutable and set to be equal to the initial aggregator decimals. If the underlying aggregator
/// is updated, the price will be normalized and the decimals of this contract will not change.
contract PythAggregatorFactory is IPythAggregatorFactory {
    /// @inheritdoc IPythAggregatorFactory
    address public immutable override pyth;

    /// @inheritdoc IPythAggregatorFactory
    mapping (bytes32 priceId => AggregatorV3Interface aggregator) public override aggregators;

    constructor(address _pyth) {
        pyth = _pyth;
    }

    /// @inheritdoc IPythAggregatorFactory
    function deploy(bytes32 _priceId) external virtual override returns (AggregatorV3Interface newAggregator) {
        if (address(aggregators[_priceId]) != address(0)) {
            revert AggregatorAlreadyExists();
        }

        newAggregator = AggregatorV3Interface(address(new PythAggregatorV3(pyth, _priceId)));
        aggregators[_priceId] = newAggregator;
        emit AggregatorDeployed(_priceId, newAggregator);
    }
}
