// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SafeCast} from "openzeppelin5/utils/math/SafeCast.sol";
import {AggregatorV3Interface} from "chainlink/v0.8/interfaces/AggregatorV3Interface.sol";

interface IStEthLike {
    function getPooledEthByShares(uint256 _sharesAmount) external view returns (uint256);
}

/// @title wstETH / stETH adapter on Ethereum mainnet.
/// @notice Adapter returns wstETH contract rate in AggregatorV3Interface interface.
/// @dev wstETH implementation uses external call to stETH to get the rate. We could use wstETH.getStETHByWstETH()
/// (it is a wrapper for stETH call), but direct call saves gas.
contract WstEthToStEthAdapterMainnet is AggregatorV3Interface {
    IStEthLike public constant STETH = IStEthLike(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);

    /// @dev Revert when getRoundData() is called.
    error NotImplemented();

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
        answer = SafeCast.toInt256(STETH.getPooledEthByShares(1 ether));
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
        return "wstETH / stETH adapter";
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
