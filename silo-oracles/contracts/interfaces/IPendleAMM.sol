// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

/// @dev https://pendle.notion.site/Cross-chain-PT-21f567a21d3780c5b7c9fe055565d762
interface IPendleAMM {
    /// @dev Call this function to preview swap PT → token
    /// @param _pt PT token
    /// @param _exactPtIn amount in.
    /// @param _token the underlying asset of the PT.
    function previewSwapExactPtForToken(
        address _pt,
        uint256 _exactPtIn,
        address _token
    ) external view returns (uint256 amountTokenOut);
}
