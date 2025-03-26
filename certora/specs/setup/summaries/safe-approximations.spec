/* Various sound summaries */

methods {
    // ---- Mathematical simplifications ---------------------------------------
    function _.mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal => cvlMulDiv(x, y, denominator) expect uint256;
}

// ---- CVL summary functions --------------------------------------------------

/// @title `mulDiv` implementation in CVL
/// @notice This will never revert!
function cvlMulDiv(uint256 x, uint256 y, uint256 denominator) returns uint {
    require denominator != 0;
    return require_uint256(x * y / denominator);
}
