// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SafeCast} from "openzeppelin5/utils/math/SafeCast.sol";
import {AggregatorV3Interface} from "chainlink/v0.8/interfaces/AggregatorV3Interface.sol";
import {IYInjPriceOracle} from "silo-oracles/contracts/custom/yINJ/interfaces/IYInjPriceOracle.sol";

/// @title YinjToInjAdapter yINJ / INJ adapter for AggregatorV3 compatibility.
/// @notice YinjToInjAdapter is an AggregatorV3 adapter for an external YInjPriceOracle.
contract YinjToInjAdapter is AggregatorV3Interface {
    /// @dev YInjPriceOracle oracle decimals.
    uint8 public constant ORACLE_DECIMALS = 18;

    /// @dev YInjPriceOracle oracle address.
    IYInjPriceOracle public immutable ORACLE; // solhint-disable-line var-name-mixedcase

    /// @dev Revert when address of YInjPriceOracle is invalid. Checks the address to return non-zero exchange rate.
    error InvalidOracleAddress();

    /// @dev Revert when getRoundData() is called.
    error NotImplemented();

    constructor(IYInjPriceOracle _oracle) {
        if (address(_oracle) == address(0) || _oracle.getExchangeRate() == 0) {
            revert InvalidOracleAddress();
        }

        ORACLE = _oracle;
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
        answer = SafeCast.toInt256(ORACLE.getExchangeRate());
        startedAt = block.timestamp;
        updatedAt = block.timestamp;
        answeredInRound = roundId;
    }

    /// @inheritdoc AggregatorV3Interface
    function decimals() external view virtual returns (uint8) {
        return ORACLE_DECIMALS;
    }

    /// @inheritdoc AggregatorV3Interface
    function description() external pure virtual returns (string memory) {
        return "yINJ / INJ adapter for YInjPriceOracle";
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
