methods {
    function _.getCompoundInterestRateAndUpdate(
        uint256 _collateralAssets,
        uint256 _debtAssets,
        uint256 _interestRateTimestamp
    ) external => simplified_getCompoundInterestRateAndUpdate(
        _collateralAssets,
        _debtAssets,
        _interestRateTimestamp
    ) expect uint256;
}

function simplified_getCompoundInterestRateAndUpdate(
    uint256 _collateralAssets,
    uint256 _debtAssets,
    uint256 _interestRateTimestamp
) returns uint256 {
    uint256 result;
    require result <= 2^16 * 10^18;

    return result;
}
