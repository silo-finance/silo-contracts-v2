// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {IERC20Metadata} from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {AggregatorV3Interface} from "chainlink/v0.8/interfaces/AggregatorV3Interface.sol";
import {ChainlinkV3OracleConfig} from "../chainlinkV3/ChainlinkV3OracleConfig.sol";

interface IChainlinkV3Oracle {
    /// @dev config based on which new oracle will be deployed
    /// @param baseToken we do not have access to tokens addresses from chainlink aggregators, so there is a need to
    /// provide them manually. Base token symbol must match aggregator description
    /// @param quoteToken we do not have access to tokens addresses from chainlink aggregators, so there is a need to
    /// provide them manually. For ETH ue WETH address.
    struct ChainlinkV3OracleInitConfig {
        IERC20Metadata baseToken;
        IERC20Metadata quoteToken;
        AggregatorV3Interface aggregator;
        uint32 heartbeat;
        AggregatorV3Interface ethAggregator;
        uint32 ethHeartbeat;
    }

    struct ChainlinkV3OracleSetup {
        AggregatorV3Interface aggregator;
        AggregatorV3Interface ethAggregator;
        uint256 heartbeat;
        uint256 ethHeartbeat;
        uint256 normalizationDivider;
        uint256 normalizationMultiplier;
        IERC20Metadata baseToken;
        IERC20Metadata quoteToken;
        bool convertToEth;
    }

    event OracleInit(ChainlinkV3OracleConfig configAddress);

    event NewAggregator(address indexed asset, AggregatorV3Interface indexed aggregator, bool convertToQuote);
    event NewHeartbeat(address indexed asset, uint256 heartbeat);
    event NewQuoteAggregatorHeartbeat(uint256 heartbeat);
    event AggregatorDisabled(address indexed asset, AggregatorV3Interface indexed aggregator);

    error AddressZero();
    error InvalidPrice();
    error InvalidPriceEth();
    error BaseAmountOverflow();

    error AggregatorDesciptionNotMatch();
    error EthAggregatorDesciptionNotMatch();
    error QuoteTokenNotMatchEth();
    error InvalidEthAggregatorDecimals();
    error InvalidHeartbeat();
    error InvalidEthHeartbeat();

    error AssetNotSupported();
}
