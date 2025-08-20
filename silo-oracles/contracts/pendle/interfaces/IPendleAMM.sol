// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface IPendleAMM {
    /// @dev Call this function to preview swap PT → token
    /// @param _PT PT token
    /// @param _exactPtIn amount in.
    /// @param _token the underlying asset of the PT.
    function previewSwapExactPtForToken(
        address _PT,
        uint256 _exactPtIn,
        address _token
    ) public view returns (uint256 amountTokenOut);
}
