// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ISiloVaultHandler {
    function depositVault(uint256 _assets, uint8 i) external;
    function mintVault(uint256 _shares, uint8 i) external;
    function withdrawVault(uint256 _assets, uint8 i) external;
    function redeemVault(uint256 _shares, uint8 i) external;
}
