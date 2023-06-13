// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

// TODO include this from silo-core
interface ISiloOracle {
    function quote(uint256 _baseAmount, address _baseToken) external returns (uint256 quoteAmount);
    function quoteView(uint256 _baseAmount, address _baseToken) external view returns (uint256 quoteAmount);
}
