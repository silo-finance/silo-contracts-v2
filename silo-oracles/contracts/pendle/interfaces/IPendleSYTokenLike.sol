// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

interface IPendleSYTokenLike {
    enum AssetType {
        TOKEN,
        LIQUIDITY
    }

    function yieldToken() external view returns (address);
    function assetInfo() external view returns (AssetType assetType, address assetAddress, uint8 assetDecimals);
}
