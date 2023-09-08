// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface ISiloOracle {
    /// @return quoteAmount Returns quote price for _baseAmount of _baseToken
    /// @param _baseAmount Amount of priced token
    /// @param _baseToken Address of priced token
    function quote(uint256 _baseAmount, address _baseToken) external view returns (uint256 quoteAmount);

    /// @notice Hook function to call before `quote` function reads price
    /// @dev This hook function can be used to change state right before the price is read. For example it can be used
    ///      for curve read reentracy protection. In majority of implemencations this will be an empty function. 
    ///      WARNING: reverts are propagated to Silo so if `beforeQuote` reverts, Silo reverts as well.
    /// @param _baseAmount Amount of priced token
    /// @param _baseToken Address of priced token
    function beforeQuote(uint256 _baseAmount, address _baseToken) external;

    function quoteToken() external view returns (address);
}
