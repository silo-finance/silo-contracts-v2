methods {
    function SiloMathLib.convertToAssets(
        uint256 _shares,
        uint256 _totalAssets,
        uint256 _totalShares,
        MathUpgradeable.Rounding _rounding,
        ISilo.AssetType _assetType
    ) internal returns (uint256) =>
    sharesToAssetsApprox(_shares, _totalAssets, _totalShares, _rounding, _assetType);

    function SiloMathLib.convertToShares(
        uint256 _assets,
        uint256 _totalAssets,
        uint256 _totalShares,
        MathUpgradeable.Rounding _rounding,
        ISilo.AssetType _assetType
    ) internal returns (uint256) =>
    assetsToSharesApprox(_assets, _totalAssets, _totalShares, _rounding, _assetType);
}

definition DECIMALS_OFFSET_POW() returns uint256 = 1;

/// shares, totalAssets, totalShares, (true if round up, false if down)
/// assets, totalShares, totalAssets, (true if round up, false if down)
ghost sharesMulDiv(uint256,uint256,uint256,bool) returns uint256 {
    axiom forall uint256 x. forall uint256 y. forall uint256 z.
        sharesMulDiv(x,y,z,true) == sharesMulDiv(x,y,z,false) ||
        sharesMulDiv(x,y,z,true) - sharesMulDiv(x,y,z,false) == 1;
    axiom forall uint256 x. forall uint256 y. forall uint256 z.
        sharesMulDiv(x,y,z,false) <= y;
    axiom forall uint256 x1. forall uint256 x2. forall uint256 y. forall uint256 z.
        sharesMulDiv(x1,y,z,false) <= sharesMulDiv(x2,y,z,false);
    axiom forall uint256 y. forall uint256 z.
        sharesMulDiv(0,y,z,false) == 0 && sharesMulDiv(y,0,z,false) == 0;
}

function sharesToAssetsApprox(
    uint256 _shares,
    uint256 _totalAssets,
    uint256 _totalShares,
    MathUpgradeable.Rounding _rounding,
    ISilo.AssetType _assetType
 ) returns uint256 {
    uint256 totalShares = _assetType == ISilo.AssetType.Debt ?
        _totalShares : require_uint256(_totalShares + DECIMALS_OFFSET_POW());
    uint256 totalAssets = _assetType == ISilo.AssetType.Debt ?
        _totalAssets : require_uint256(_totalAssets + 1);

    if (totalShares == 0 || totalAssets == 0) return _shares;

    return sharesMulDiv(_shares,totalAssets,totalShares,_rounding == MathUpgradeable.Rounding.Up);
}

function assetsToSharesApprox(
    uint256 _assets,
    uint256 _totalAssets,
    uint256 _totalShares,
    MathUpgradeable.Rounding _rounding,
    ISilo.AssetType _assetType
) returns uint256 {
    uint256 totalShares = _assetType == ISilo.AssetType.Debt ?
        _totalShares : require_uint256(_totalShares + DECIMALS_OFFSET_POW());
    uint256 totalAssets = _assetType == ISilo.AssetType.Debt ?
        _totalAssets : require_uint256(_totalAssets + 1);

    if (totalShares == 0 || totalAssets == 0) return _assets;

    return sharesMulDiv(_assets,totalShares,totalAssets,_rounding == MathUpgradeable.Rounding.Up);
}
