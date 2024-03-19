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
    /// Symmetry:
        sharesMulDiv(x,y,z,false) == sharesMulDiv(y,x,z,false) &&
        sharesMulDiv(x,y,z,true) == sharesMulDiv(y,x,z,true) &&
    /// For shares conversion calculations, one expects 
    ///     shares <= total shares
    ///     assets <= total assets
    /// hence : x <= z => assets (shares) = x * y / z <= y = total assets (total shares)
        (sharesMulDiv(x,y,z,false) <= y) &&
        ((x == z && z !=0) => sharesMulDiv(x,y,z,false) == y) &&
        ((y == z && z !=0) => sharesMulDiv(x,y,z,false) == x);

    axiom forall uint256 x1. forall uint256 x2. forall uint256 y. forall uint256 z.
        x1 <= x2 => sharesMulDiv(x1,y,z,false) <= sharesMulDiv(x2,y,z,false);
    axiom forall uint256 x1. forall uint256 x2. forall uint256 y. forall uint256 z.
        x1 <= x2 => sharesMulDiv(x1,y,z,true) <= sharesMulDiv(x2,y,z,true);
    axiom forall uint256 y1. forall uint256 y2. forall uint256 x. forall uint256 z.
        y1 <= y2 => sharesMulDiv(x,y1,z,false) <= sharesMulDiv(x,y2,z,false);
    axiom forall uint256 y1. forall uint256 y2. forall uint256 x. forall uint256 z.
        y1 <= y2 => sharesMulDiv(x,y1,z,true) <= sharesMulDiv(x,y2,z,true);
    axiom forall uint256 z1. forall uint256 z2. forall uint256 x. forall uint256 y.
        z1 <= z2 => sharesMulDiv(x,y,z1,false) >= sharesMulDiv(x,y,z2,false);
    axiom forall uint256 y. forall uint256 z.
        (sharesMulDiv(0,y,z,false) == 0) && 
        (sharesMulDiv(1,y,z,false) ==0 <=> (y ==0 || y < z));
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
/*
prove that x - roundUp( (z-1) / y ) <= muldivDown(w, z, y) <= x
where w = muldivDown(x,y,z)
*/
/// Verified
/// https://prover.certora.com/output/41958/dd34d0c3c49844c6991899722f457a10/?anonymousKey=f1457c818051cf4f05871dee2529272699803159
rule assetsToSharesAndBackAxiom(uint256 x, uint256 y, uint256 z) {
    require z !=0;
    require y !=0;
    uint256 w = require_uint256(x * y / z);
    uint256 xp = require_uint256(w * z / y);
    mathint delta = (1 * (z - 1)) / y;

    assert xp <= x && to_mathint(xp) >= x - delta - 1;
}