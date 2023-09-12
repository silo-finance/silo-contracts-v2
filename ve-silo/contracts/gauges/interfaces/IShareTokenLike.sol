// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

interface IShareTokenLike {
    function balanceOf(address _user) external view returns (uint256 balance);
    function totalSupply() external view returns (uint256 totalSupply);
    function silo() external view returns (address silo);
    function balanceOfAndTotalSupply(address _user) external view returns (uint256 balance, uint256 totalSupply);
}
