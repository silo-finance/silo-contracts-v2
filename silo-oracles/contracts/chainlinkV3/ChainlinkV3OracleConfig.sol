// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {IERC20Metadata} from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {AggregatorV3Interface} from "chainlink/v0.8/interfaces/AggregatorV3Interface.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {IChainlinkV3Oracle} from "../interfaces/IChainlinkV3Oracle.sol";
import {L1OracleConfig} from "../_common/L1OracleConfig.sol";

contract ChainlinkV3OracleConfig is L1OracleConfig {
    AggregatorV3Interface internal immutable _AGGREGATOR; // solhint-disable-line var-name-mixedcase

    /// @dev Chainlink aggregator proxy for ETH/USD price, used only when convertToEth
    AggregatorV3Interface internal immutable _ETH_AGGREGATOR; // solhint-disable-line var-name-mixedcase

    /// @dev Threshold used to determine if the price returned by the ETH_AGGREGATOR is valid
    uint256 internal immutable _ETH_HEARTBEAT; // solhint-disable-line var-name-mixedcase

    uint256 internal immutable _PRICE_DECIMALS; // solhint-disable-line var-name-mixedcase

    /// @dev this can be set to true to convert price in USD to price in ETH
    /// assuming that AGGREGATOR providing price in USD
    bool internal immutable _CONVERT_TO_ETH; // solhint-disable-line var-name-mixedcase

    /// @dev all verification should be done by factory
    constructor(
        IChainlinkV3Oracle.ChainlinkV3OracleInitConfig memory _config,
        uint256 _normalizationDivider,
        uint256 _normalizationMultiplier
    )
        L1OracleConfig(
            _config.baseToken,
            _config.quoteToken,
            _config.heartbeat,
            _normalizationDivider,
            _normalizationMultiplier
        )
    {
        _AGGREGATOR = _config.aggregator;
        _ETH_AGGREGATOR = _config.ethAggregator;
        _ETH_HEARTBEAT = _config.ethHeartbeat;
        _CONVERT_TO_ETH = address(_config.ethAggregator) != address(0);

        _PRICE_DECIMALS = _config.aggregator.decimals();
    }

    function getSetup() external view virtual returns (IChainlinkV3Oracle.ChainlinkV3OracleSetup memory setup) {
        setup.aggregator = _AGGREGATOR;
        setup.ethAggregator = _ETH_AGGREGATOR;
        setup.heartbeat = _HEARTBEAT;
        setup.ethHeartbeat = _ETH_HEARTBEAT;
        setup.normalizationDivider = _DECIMALS_NORMALIZATION_DIVIDER;
        setup.normalizationMultiplier = _DECIMALS_NORMALIZATION_MULTIPLIER;
        setup.baseToken = _BASE_TOKEN;
        setup.quoteToken = _QUOTE_TOKEN;
        setup.convertToEth = _CONVERT_TO_ETH;
    }
}
