// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {AggregatorV3Interface} from "chainlink/v0.8/interfaces/AggregatorV3Interface.sol";
import {TokenHelper} from "silo-core/contracts/lib/TokenHelper.sol";
import {SafeCast} from "openzeppelin5/utils/math/SafeCast.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

abstract contract Aggregator is AggregatorV3Interface {
    /// @notice all Silo oracles should return price in 18 decimals
    function decimals() external view virtual returns (uint8) {
        return 18;
    }

    function description() external view virtual returns (string memory) {
        return "Silo Oracle";
    }

    function version() external pure returns (uint256) {
        return 1;
    }

    /// @notice not in use, always returns 0s, use latestRoundData instead
    function getRoundData(uint80)
        external
        pure
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (0, 0, 0, 0, 0);
    }

    /// @notice this function follows the Chainlink V3 interface but only answer is used,
    /// all other return values are zero
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
        roundId = 0;
        address token = baseToken();
        uint256 tokenDecimals = TokenHelper.assertAndGetDecimals(token);
        ISiloOracle oracle = ISiloOracle(address(this));
        answer = SafeCast.toInt256(oracle.quote(10 ** tokenDecimals, token));

        startedAt = block.timestamp;
        updatedAt = block.timestamp;
        answeredInRound = 0;
    }
    
    function baseToken() public view virtual returns (address token);
}
