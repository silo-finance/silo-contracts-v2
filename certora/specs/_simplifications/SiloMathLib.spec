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
persistent ghost sharesMulDiv(uint256,uint256,uint256,bool) returns uint256 {
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

function mulDivDown_mathLib(uint256 x, uint256 y, uint256 z) returns uint256 {
    require z !=0 && x * y <= max_uint256;
    return assert_uint256(x * y / z);
}

function mulDivUp_mathLib(uint256 x, uint256 y, uint256 z) returns uint256 {
    require z !=0 && x * y + z - 1 <= max_uint256;
    return assert_uint256((x * y + z - 1) / z);
}

/// Verified
rule mulDiv_axioms_test(uint256 x, uint256 y, uint256 z) {
    uint256 resDown = mulDivDown_mathLib(x,y,z);
    uint256 resUp = mulDivUp_mathLib(x,y,z);

    uint256 resDown_sym = mulDivDown_mathLib(y,x,z);
    uint256 resUp_sym = mulDivUp_mathLib(y,x,z);
    
    uint256 xp;
    uint256 zp;
    uint256 resDown_xp = mulDivDown_mathLib(xp,y,z);
    uint256 resUp_xp = mulDivUp_mathLib(xp,y,z);
    uint256 resDown_zp = mulDivDown_mathLib(x,y,zp);
    uint256 resUp_zp = mulDivUp_mathLib(x,y,zp);

    assert resDown == resUp || resUp - resDown == 1;
    assert resDown_sym == resDown;
    assert resUp == resUp_sym;
    assert x <= z => resDown <= y;
    assert (x == z && z !=0) => resDown == y;
    assert (y == z && z !=0) => resDown == x;
    assert x <= xp => resDown <= resDown_xp;
    assert x <= xp => resUp <= resUp_xp;
    assert z <= zp => resDown >= resDown_zp;
    assert z <= zp => resUp >= resUp_zp;
    assert (x == 0) => resDown == 0;
    assert (x == 1) => (resDown ==0 <=> (y ==0 || y < z));
}

/*
prove that x - roundUp( (z-1) / y ) <= muldivDown(w, z, y) <= x
where w = muldivDown(x,y,z)
*/
/// Verified
rule assetsToSharesAndBackAxiom(uint256 x, uint256 y, uint256 z) {
    uint256 w = mulDivDown_mathLib(x, y, z);
    uint256 xp = mulDivDown_mathLib(w, z, y);
    mathint delta = mulDivDown_mathLib(1, assert_uint256(z - 1), y);

    assert xp <= x && to_mathint(xp) >= x - delta - 1;
}