methods {
    function SiloMathLib.convertToAssets(
        uint256 _shares,
        uint256 _totalAssets,
        uint256 _totalShares,
        MathUpgradeable.Rounding _rounding,
        ISilo.AssetType _assetType
    ) internal returns (uint256) => simplified_convertToAssets(
        _shares,
        _totalAssets,
        _totalShares,
        _rounding,
        _assetType
    );

    function SiloMathLib.convertToShares(
        uint256 _assets,
        uint256 _totalAssets,
        uint256 _totalShares,
        MathUpgradeable.Rounding _rounding,
        ISilo.AssetType _assetType
    ) internal returns (uint256) => simplified_convertToShares(
        _assets,
        _totalAssets,
        _totalShares,
        _rounding,
        _assetType
    );
}

function simplified_convertToShares(
    uint256 _assets,
    uint256 _totalAssets,
    uint256 _totalShares,
    MathUpgradeable.Rounding _rounding,
    ISilo.AssetType _assetType
) returns uint256 {
    if (_rounding == MathUpgradeable.Rounding.Up) {
        return assert_uint256(_assets / 5 * 3 + 1);
    }

    return assert_uint256(_assets / 5 * 3);
}

function simplified_convertToAssets(
    uint256 _shares,
    uint256 _totalAssets,
    uint256 _totalShares,
    MathUpgradeable.Rounding _rounding,
    ISilo.AssetType _assetType
) returns uint256 {
    require _shares * 2 < max_uint256;

    if (_rounding == MathUpgradeable.Rounding.Up) {
        return assert_uint256(_shares * 5 / 3 + 1);
    }

    return assert_uint256(_shares * 5 / 3);
}
