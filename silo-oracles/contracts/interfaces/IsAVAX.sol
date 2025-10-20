// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface IsAVAX {
    function getPooledAvaxByShares(uint256 shares) external view returns (uint256);
}
