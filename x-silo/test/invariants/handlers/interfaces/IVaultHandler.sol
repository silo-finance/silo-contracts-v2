// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IVaultHandler {
    function deposit(
        uint256 _assets,
        uint8 i,
        uint8 j,
        uint8 k
    ) external;

    function mint(
        uint256 _shares,
        uint8 i,
        uint8 j,
        uint8 k
    ) external;

    function withdraw(
        uint256 _assets,
        uint8 i,
        uint8 j,
        uint8 k
    ) external;

    function redeem(
        uint256 _shares,
        uint8 i,
        uint8 j,
        uint8 k
    ) external;
}
