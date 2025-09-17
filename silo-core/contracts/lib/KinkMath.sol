// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

library KinkMath {
    /// @notice Check if a value is within a closed interval [a, b]
    /// @dev Mathematical notation: x ∈ [a, b] where a ≤ x ≤ b
    /// @param _var The value to check
    /// @param _lowIncluded Lower bound (inclusive)
    /// @param _topIncluded Upper bound (inclusive)
    /// @return isWithinInterval true if _var is within the closed interval
    function inClosedInterval(
        int256 _var, 
        int256 _lowIncluded, 
        int256 _topIncluded
    ) internal pure returns (bool isWithinInterval) {
        return (_lowIncluded <= _var && _var <= _topIncluded);
    }

    /// @notice Check if a value is within a half-open interval [a, b)
    /// @dev Mathematical notation: x ∈ [a, b) where a ≤ x < b
    /// @param _var The value to check
    /// @param _lowIncluded Lower bound (inclusive)
    /// @param _topExcluded Upper bound (exclusive)
    /// @return isWithinInterval true if _var is within the half-open interval
    function inOpenIntervalLowIncluded(
        int256 _var, 
        int256 _lowIncluded, 
        int256 _topExcluded
    ) internal pure returns (bool isWithinInterval) {
        return (_lowIncluded <= _var && _var < _topExcluded);
    }

    /// @notice Check if a value is within a half-open interval (a, b]
    /// @dev Mathematical notation: x ∈ (a, b] where a < x ≤ b
    /// @param _var The value to check
    /// @param _lowExcluded Lower bound (exclusive)
    /// @param _topIncluded Upper bound (inclusive)
    /// @return isWithinInterval true if _var is within the half-open interval
    function inOpenIntervalTopIncluded(
        int256 _var, 
        int256 _lowExcluded, 
        int256 _topIncluded
    ) internal pure returns (bool isWithinInterval) {
        return (_lowExcluded < _var && _var <= _topIncluded);
    }

    /// @notice Check if a value is within an open interval (a, b)
    /// @dev Mathematical notation: x ∈ (a, b) where a < x < b
    /// @param _var The value to check
    /// @param _lowExcluded Lower bound (exclusive)
    /// @param _topExcluded Upper bound (exclusive)
    /// @return isWithinInterval true if _var is within the open interval
    function inOpenInterval(
        int256 _var, 
        int256 _lowExcluded, 
        int256 _topExcluded
    ) internal pure returns (bool isWithinInterval) {
        return (_lowExcluded < _var && _var < _topExcluded);
    }

    /// @notice Check if a uint256 value would overflow when cast to int256
    /// @dev This is a safety check for casting unsigned to signed integers
    /// @param _value The uint256 value to check
    /// @return wouldOverflow true if casting would cause overflow
    function wouldOverflowOnCastToInt256(uint256 _value) internal pure returns (bool wouldOverflow) {
        return _value > uint256(type(int256).max); // TODO check openzeppelin SafeCast.sol
    }
}
