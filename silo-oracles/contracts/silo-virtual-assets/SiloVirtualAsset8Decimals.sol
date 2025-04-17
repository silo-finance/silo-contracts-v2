// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

contract SiloVirtualAsset8Decimals {
    function name() external pure returns (string memory) {
        return "Silo Virtual Asset";
    }

    function symbol() external pure returns (string memory) {
        return "SVA8D";
    }

    function decimals() external pure returns (uint8) {
        return 8;
    }
}
