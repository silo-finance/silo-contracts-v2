// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

contract DexSwapMock {
    fallback(bytes calldata) external returns (bytes memory) {
        // do not revert
        return "";
    }
}
