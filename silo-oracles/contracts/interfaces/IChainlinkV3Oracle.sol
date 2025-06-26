// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";
import {AggregatorV3Interface} from "chainlink/v0.8/interfaces/AggregatorV3Interface.sol";
import {ChainlinkV3OracleConfig} from "../chainlinkV3/ChainlinkV3OracleConfig.sol";

interface IChainlinkV3Oracle {
    /// @dev config based on which new oracle will be deployed
    /// @notice there is no way to check if aggregators match tokens, so it is users job to verify config.
    /// @param primaryAggregator used to read price from chainlink, if it can not provide price in quote token,
    /// then you have to setup secondary one that will do the job
    /// @param secondaryAggregator if set, it is used translate primary price into quote price eg:
    /// primary price is ABC/USD and secondary is ETH/USD, then result will be price in ABC/ETH
    /// @param baseToken base token address, it must have decimals() method available
    /// @param quoteToken quote toke address, it must have decimals() method available
    /// @param primaryHeartbeat heartbeat of primary price
    /// @param secondaryHeartbeat heartbeat of secondary price
    /// @param normalizationDivider divider that will be used in oracle to normalize price
    /// @param normalizationMultiplier multiplier that will be used in oracle to normalize price
    /// @param invertSecondPrice in case we using second price, this flag will tell us if we need to 1/secondPrice
    struct ChainlinkV3DeploymentConfig {
        IERC20Metadata baseToken;
        IERC20Metadata quoteToken;
        AggregatorV3Interface primaryAggregator;
        uint32 primaryHeartbeat;
        AggregatorV3Interface secondaryAggregator;
        uint32 secondaryHeartbeat;
        uint256 normalizationDivider;
        uint256 normalizationMultiplier;
        bool invertSecondPrice;
    }

    /// @dev config based on which new oracle will be deployed
    /// @notice there is no way to check if aggregators match tokens, so it is users job to verify config.
    /// @param primaryAggregator used to read price from chainlink, if it can not provide price in quote token,
    /// then you have to setup secondary one that will do the job
    /// @param secondaryAggregator if set, it is used translate primary price into quote price eg:
    /// primary price is ABC/USD and secondary is ETH/USD, then result will be price in ABC/ETH
    /// @param baseToken base token address, it must have decimals() method available
    /// @param quoteToken quote toke address, it must have decimals() method available
    /// @param primaryHeartbeat heartbeat of primary price
    /// @param secondaryHeartbeat heartbeat of secondary price
    /// @param invertSecondPrice in case we using second price, this flag will tell us if we need to 1/secondPrice
    struct ChainlinkV3Config {
        AggregatorV3Interface primaryAggregator;
        AggregatorV3Interface secondaryAggregator;
        uint256 primaryHeartbeat;
        uint256 secondaryHeartbeat;
        uint256 normalizationDivider;
        uint256 normalizationMultiplier;
        IERC20Metadata baseToken;
        IERC20Metadata quoteToken;
        bool convertToQuote;
        bool invertSecondPrice;
    }

    event ChainlinkV3ConfigDeployed(ChainlinkV3OracleConfig configAddress);

    event NewAggregator(address indexed asset, AggregatorV3Interface indexed aggregator, bool convertToQuote);
    event NewHeartbeat(address indexed asset, uint256 heartbeat);
    event NewQuoteAggregatorHeartbeat(uint256 heartbeat);
    event AggregatorDisabled(address indexed asset, AggregatorV3Interface indexed aggregator);

    error AddressZero();
    error InvalidPrice();
    error ZeroQuote();
    error InvalidSecondPrice();
    error BaseAmountOverflow();
    error TokensAreTheSame();
    error AggregatorsAreTheSame();

    error QuoteTokenNotMatchEth();
    error InvalidEthAggregatorDecimals();

    error AssetNotSupported();
    error HugeDivider();
    error HugeMultiplier();
    error MultiplierAndDividerZero();
}
