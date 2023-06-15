// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

interface ISiloOracle {
    function quote(uint256 _baseAmount, address _baseToken) external returns (uint256 quoteAmount);
    function quoteView(uint256 _baseAmount, address _baseToken) external view returns (uint256 quoteAmount);
}
