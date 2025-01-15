// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {AggregatorV3Interface} from "chainlink/v0.8/interfaces/AggregatorV3Interface.sol";
import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";

/// @notice UpgradableAggregator is an ownable contract which forwards AggregatorV3Interface calls to the underlying
/// feed. Decimals are immutable and set to be equal to the initial aggregator decimals. If the underlying aggregator
/// is updated, the price will be normalized and the decimals of this contract will not change.
contract UpgradableAggregator is AggregatorV3Interface, Ownable2Step {
    /// @dev Initial aggregator decimals.
    uint8 public immutable AGGREGATOR_DECIMALS; // solhint-disable-line var-name-mixedcase

    /// @dev Underlying aggregator to forward contract calls. Can be changed by the owner. New underlying feed tickers
    /// must match the initial underlying feed tickers. For example, if the feed was ETH/USD, new feed must be ETH/USD.
    /// Decimals of the new feed can be different, the price will be normalized.
    AggregatorV3Interface public underlyingFeed;

    event UnderlyingFeedUpdated(AggregatorV3Interface indexed newUnderlyingFeed);

    constructor(address _initialOwner, AggregatorV3Interface _initialAggregator) Ownable(_initialOwner) {
        // initial feed must not revert
        _initialAggregator.latestRoundData();

        AGGREGATOR_DECIMALS = _initialAggregator.decimals();
        underlyingFeed = _initialAggregator;
    }

    function decimals() external view virtual override returns (uint8) {
        return AGGREGATOR_DECIMALS;
    }

    function description() external view virtual override returns (string memory) {
        return underlyingFeed.description();
    }

    function version() external view virtual override returns (uint256) {
        return underlyingFeed.version();
    }

    function getRoundData(uint80 _roundId)
        external
        view
        virtual
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        (roundId, answer, startedAt, updatedAt, answeredInRound) = underlyingFeed.getRoundData(_roundId);
        answer = _normalizePriceWithDecimals(answer, underlyingFeed.decimals());
    }

    function latestRoundData()
        external
        view
        virtual
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        (roundId, answer, startedAt, updatedAt, answeredInRound) = underlyingFeed.latestRoundData();
        answer = _normalizePriceWithDecimals(answer, underlyingFeed.decimals());
    }

    function changeUnderlyingFeed(AggregatorV3Interface _newUnderlyingFeed) external virtual onlyOwner {
        // new feed must not revert
        _newUnderlyingFeed.latestRoundData();

        underlyingFeed = _newUnderlyingFeed;
        emit UnderlyingFeedUpdated(_newUnderlyingFeed);
    }

    /// @dev Adjust the _underlyingAnswer from underlying feed with _underlyingDecimals to be compatible with
    /// AGGREGATOR_DECIMALS.
    function _normalizePriceWithDecimals(int256 _underlyingAnswer, uint8 _underlyingDecimals) 
        internal
        view
        virtual
        returns (int256 normalizedAnswer) 
    {
        if (_underlyingDecimals <= AGGREGATOR_DECIMALS) {
            normalizedAnswer = _underlyingAnswer * int256(10 ** uint256(AGGREGATOR_DECIMALS - _underlyingDecimals));
        } else {
            normalizedAnswer = _underlyingAnswer / int256(10 ** uint256(_underlyingDecimals - AGGREGATOR_DECIMALS));
        }
    }
}
