// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IStEthLike {
    function getPooledEthByShares(uint256 _sharesAmount) external view returns (uint256);
}
