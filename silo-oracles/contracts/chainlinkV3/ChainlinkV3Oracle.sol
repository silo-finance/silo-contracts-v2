// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Initializable} from  "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC20Metadata} from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {AggregatorV3Interface} from "chainlink/v0.8/interfaces/AggregatorV3Interface.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

import {OracleNormalization} from "../lib/OracleNormalization.sol";
import {ChainlinkV3OracleConfig} from "./ChainlinkV3OracleConfig.sol";
import {IChainlinkV3Oracle} from "../interfaces/IChainlinkV3Oracle.sol";

contract ChainlinkV3Oracle is IChainlinkV3Oracle, ISiloOracle, Initializable {
    ChainlinkV3OracleConfig public oracleConfig;

    /// @notice validation of config is checked in factory, therefore you should not deploy and initialize directly
    /// use factory always.
    function initialize(ChainlinkV3OracleConfig _configAddress) external virtual initializer {
        oracleConfig = _configAddress;

        IERC20Metadata baseToken = _configAddress.getSetup().baseToken;
        // sanity check of price for 1 TOKEN
        _quote(10 ** baseToken.decimals(), address(baseToken));

        emit OracleInit(_configAddress);
    }

    /// @inheritdoc ISiloOracle
    // TODO WHY DO WE NEED THIS "VIEW"??
    function quote(uint256 _baseAmount, address _baseToken) external virtual returns (uint256 quoteAmount) {
        return _quote(_baseAmount, _baseToken);
    }

    /// @dev Returns price directly from aggregator, this method is mostly for debug purposes
    function getAggregatorPrice() external view virtual returns (bool success, uint256 price) {
        IChainlinkV3Oracle.ChainlinkV3OracleSetup memory setup = oracleConfig.getSetup();
        return _getAggregatorPrice(setup.aggregator, setup.heartbeat);
    }

    /// @dev Returns price directly from aggregator, this method is mostly for debug purposes
    function getAggregatorPriceEth() external view virtual returns (bool success, uint256 price) {
        IChainlinkV3Oracle.ChainlinkV3OracleSetup memory setup = oracleConfig.getSetup();
        return _getAggregatorPrice(setup.ethAggregator, setup.ethHeartbeat);
    }

    /// @inheritdoc ISiloOracle
    function quoteView(uint256 _baseAmount, address _baseToken) external view virtual returns (uint256 quoteAmount) {
        return _quote(_baseAmount, _baseToken);
    }

    /// @inheritdoc ISiloOracle
    function quoteToken() external view virtual returns (address) {
        IChainlinkV3Oracle.ChainlinkV3OracleSetup memory setup = oracleConfig.getSetup();
        return address(setup.quoteToken);
    }

    function _quote(uint256 _baseAmount, address _baseToken) internal view virtual returns (uint256 quoteAmount) {
        ChainlinkV3OracleSetup memory data = oracleConfig.getSetup();

        if (_baseToken != address(data.baseToken)) revert AssetNotSupported();
        if (_baseAmount > type(uint128).max) revert BaseAmountOverflow();

        (bool success, uint256 price) = _getAggregatorPrice(data.aggregator, data.heartbeat);
        if (!success) revert InvalidPrice();

        if (!data.convertToEth) {
            return OracleNormalization.normalizePrice(
                _baseAmount, price, data.normalizationDivider, data.normalizationMultiplier
            );
        }

        (bool ethSuccess, uint256 ethPriceInUsd) = _getAggregatorPrice(data.ethAggregator, data.heartbeat);
        if (!ethSuccess) revert InvalidPriceEth();

        return OracleNormalization.normalizePriceEth(
            _baseAmount,
            price,
            ethPriceInUsd,
            data.normalizationDivider,
            data.normalizationMultiplier
        );
    }

    function _getAggregatorPrice(AggregatorV3Interface _aggregator, uint256 _heartbeat)
        internal
        view
        virtual
        returns (bool success, uint256 price)
    {
        (
            /*uint80 roundID*/,
            int256 aggregatorPrice,
            /*uint256 startedAt*/,
            uint256 priceTimestamp,
            /*uint80 answeredInRound*/
        ) = _aggregator.latestRoundData();

        // price must be updated at least once every _heartbeat, otherwise something is wrong
        uint256 oldestAcceptedPriceTimestamp;
        // block.timestamp is more than HEARTBEAT, so we can not underflow
        unchecked { oldestAcceptedPriceTimestamp = block.timestamp - _heartbeat; }

        if (aggregatorPrice > 0 && priceTimestamp > oldestAcceptedPriceTimestamp) {
            return (true, uint256(aggregatorPrice));
        }

        return (false, 0);
    }
}
