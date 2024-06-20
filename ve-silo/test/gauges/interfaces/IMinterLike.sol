// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

// interfaces for tests
interface IMinterLike {
    function minted(address _user,address _gauge) external view returns (uint256);
    function getBalancerToken() external view returns (uint256);
}
