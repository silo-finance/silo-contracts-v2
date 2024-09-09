// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

interface IChainlinkPriceFeedLike {
    /// @notice Token price in USD.
    /// @dev RMN depends on this struct, if changing, please notify the RMN maintainers.
    struct TokenPriceUpdate {
        address sourceToken; // Source token
        uint224 usdPerToken; // 1e18 USD per smallest unit of token
    }

    /// @notice Gas price for a given chain in USD, its value may contain tightly packed fields.
    /// @dev RMN depends on this struct, if changing, please notify the RMN maintainers.
    struct GasPriceUpdate {
        uint64 destChainSelector; // Destination chain selector
        uint224 usdPerUnitGas; // 1e18 USD per smallest unit (e.g. wei) of destination chain gas
    }

    struct PriceUpdates {
        TokenPriceUpdate[] tokenPriceUpdates;
        GasPriceUpdate[] gasPriceUpdates;
    }

    function updatePrices(PriceUpdates calldata priceUpdates) external;
}
