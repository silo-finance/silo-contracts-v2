// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

interface IShareTokenLike {
    function balanceOf(address _user) external view returns (uint256 balance);
    function totalSupply() external view returns (uint256 totalSupply);
    function silo() external view returns (address silo);
    function hookReceiver() external view returns (address hook);
    function balanceOfAndTotalSupply(address _user) external view returns (uint256 balance, uint256 totalSupply);
}
