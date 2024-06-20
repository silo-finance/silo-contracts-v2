// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

// interfaces for tests
interface IVotingEscrowDelegationProxyLike {
    function totalSupply() external view returns (uint256);
    function adjustedBalanceOf(address _user) external view returns (uint256);
}
