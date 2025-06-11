// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IWrappedMetaVaultOracle} from "./interfaces/IWrappedMetaVaultOracle.sol";
import {AggregatorV3Interface} from "chainlink/v0.8/interfaces/AggregatorV3Interface.sol";
import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";

/// @title WrappedMetaVaultOracleAdapter adapter for IWrappedMetaVaultOracle feeds.
/// @notice Adapter returns price with the latest block timestamp for ChainlinkV3Oracle compatibility.
contract WrappedMetaVaultOracleAdapter is AggregatorV3Interface {
    /// @dev Price source feed address.
    IWrappedMetaVaultOracle public immutable FEED; // solhint-disable-line var-name-mixedcase

    /// @dev Price decimals cached from FEED.
    uint8 public immutable DECIMALS; // solhint-disable-line var-name-mixedcase

    /// @dev Revert in constructor when price is zero to check setup.
    error FeedHasZeroPrice();
    error NotImplemented();

    constructor(IWrappedMetaVaultOracle _feed) {
        if (_feed.latestAnswer() == 0) {
            revert FeedHasZeroPrice();
        }

        FEED = _feed;
        DECIMALS = _feed.decimals();
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
        answer = FEED.latestAnswer();
        startedAt = block.timestamp;
        updatedAt = block.timestamp;
        answeredInRound = roundId;
    }

    /// @inheritdoc AggregatorV3Interface
    function decimals() external view virtual returns (uint8) {
        return DECIMALS;
    }

    /// @inheritdoc AggregatorV3Interface
    function description() external view virtual returns (string memory) {
        return string.concat(
            "WrappedMetaVaultOracleAdapter for ",
            IERC20Metadata(FEED.wrappedMetaVault()).name()
        );
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
