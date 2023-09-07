// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

interface IERC20BalancesHandler {
    function balanceOf(address _user) external view returns (uint256 balance);
    function totalSupply() external view returns (uint256 totalSupply);
    function balanceOfAndTotalSupply(address _user) external view returns (uint256 balance, uint256 totalSupply);
}
