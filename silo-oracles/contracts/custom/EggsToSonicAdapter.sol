// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SafeCast} from "openzeppelin5/utils/math/SafeCast.sol";
import {AggregatorV3Interface} from "chainlink/v0.8/interfaces/AggregatorV3Interface.sol";

/// @dev part of EGGS contract interface to get the EGGS / S exchange rate
interface IEggsLike {
    function EGGStoSONIC(uint256 value) external view returns (uint256);
}

/// @title EGGS / S adapter
/// @notice EggsToSonic is the adapter for EGGS / S price feed. Price is equal to EGGS internal rate of
/// `EGGStoSONIC()` multiplied by 98.9%.
contract EggsToSonicAdapter is AggregatorV3Interface {
    /// @dev Sample amount for EGGS / S conversion rate calculations
    uint256 public constant SAMPLE_AMOUNT = 10 ** 18;

    /// @dev rate is be multiplied by RATE_MULTIPLIER and divided by RATE_DIVIDER to get 98.9% of original rate.
    int256 public constant RATE_DIVIDER = 1000;
    int256 public constant RATE_MULTIPLIER = 989;

    /// @dev EGGS asset address
    IEggsLike public immutable EGGS; // solhint-disable-line var-name-mixedcase

    /// @dev Revert when address of EGGS is invalid. Checks the address to return non-zero EGGStoSONIC rate.
    error InvalidEggsAddress();

    /// @dev Revert when getRoundData() is called.
    error NotImplemented();

    constructor(IEggsLike _eggs) {
        if (address(_eggs) == address(0) || _eggs.EGGStoSONIC(SAMPLE_AMOUNT) == 0) {
            revert InvalidEggsAddress();
        }

        EGGS = _eggs;
    }

    /// @inheritdoc AggregatorV3Interface
    function latestRoundData()
        external
        view
        virtual
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        roundId = 1;
        answer = SafeCast.toInt256(EGGS.EGGStoSONIC(SAMPLE_AMOUNT)) * RATE_MULTIPLIER / RATE_DIVIDER;
        startedAt = block.timestamp;
        updatedAt = block.timestamp;
        answeredInRound = roundId;
    }

    /// @inheritdoc AggregatorV3Interface
    function decimals() external view virtual returns (uint8) {
        return 18;
    }

    /// @inheritdoc AggregatorV3Interface
    function description() external pure virtual returns (string memory) {
        return "EGGS / S adapter";
    }

    /// @inheritdoc AggregatorV3Interface
    function version() external pure virtual returns (uint256) {
        return 1;
    }

    /// @inheritdoc AggregatorV3Interface
    function getRoundData(uint80) external pure virtual returns (uint80, int256, uint256, uint256, uint80) {
        revert NotImplemented();
    }
}
