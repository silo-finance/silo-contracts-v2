// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {AggregatorV3Interface} from "chainlink/v0.8/interfaces/AggregatorV3Interface.sol";
import {TokenHelper} from "silo-core/contracts/lib/TokenHelper.sol";

abstract contract Aggregator is AggregatorV3Interface {
    /// @notice all Silo oracles should return price in 18 decimals
    function decimals() external view virtual returns (uint8) {
        return 18;
    }

    function description() external view virtual returns (string memory) {
        return "Silo Oracle";
    }

    function version() external view returns (uint256) {
        return 1;
    }

    /// @notice not supported
    function getRoundData(uint80)
        external
        view
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
        address token = baseToken();
        uint256 decimals = TokenHelper.assertAndGetDecimals(token);
        answer = quote(10 ** decimals, token);

        startedAt = block.timestamp;
        updatedAt = block.timestamp;
    }

    function quote(uint256 _baseAmount, address _baseToken) public view virtual returns (uint256 quoteAmount);
    
    function baseToken() public view virtual returns (address token);
}
