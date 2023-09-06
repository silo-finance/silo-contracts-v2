// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface ISiloOracle {
    /// @return quoteAmount Returns quote price for _baseAmount of _baseToken
    /// @param _baseAmount Amount of priced token
    /// @param _baseToken Address of priced token
    function quote(uint256 _baseAmount, address _baseToken) external returns (uint256 quoteAmount);

    /// @return quoteAmount Returns quoteAmount quote price for _baseAmount of _baseToken
    /// @param _baseAmount Amount of priced token
    /// @param _baseToken Address of priced token
    function quoteView(uint256 _baseAmount, address _baseToken) external view returns (uint256 quoteAmount);

    function quoteToken() external view returns (address);
}
