// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

contract SiloVirtualAsset18Decimals {
    function name() external pure returns (string memory) {
        return "Silo Virtual Asset";
    }

    function symbol() external pure returns (string memory) {
        return "SVA18D";
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }
}
