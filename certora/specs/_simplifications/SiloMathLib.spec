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

    function SiloMathLib.getDebtAmountsWithInterest(uint256 _debtAssets, uint256 _rcomp) 
        internal returns (uint256,uint256) => getDebtAmountsWithInterestCVL(_debtAssets, _rcomp);
}

definition DECIMALS_OFFSET_POW() returns uint256 = 1;
definition PRECISION_DECIMALS() returns uint256 = 10^18;

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

    axiom forall uint256 x. forall uint256 y. forall uint256 z. forall uint256 w.
        (w == sharesMulDiv(x,y,z,false) && y !=0) => (
            sharesMulDiv(w,z,y,false) <= x && 
            sharesMulDiv(w,z,y,false) + sharesMulDiv(z,1,y,true) >= to_mathint(x));
}

/// interestRatio(_debtAssets,_rcomp) = _debtAssets * _rcomp / _PRECISION_DECIMALS;
persistent ghost interestRatio(uint256,uint256) returns uint256 {
    axiom forall uint256 x1. forall uint256 x2. forall uint256 y.
        x1 <= x2 => (
            interestRatio(x1,y) <= interestRatio(x2,y) &&
            interestRatio(y,x1) <= interestRatio(y,x2)
        );
    axiom forall uint256 x. forall uint256 y.
        (interestRatio(x,y) == interestRatio(y,x)) &&
        (y > PRECISION_DECIMALS() => interestRatio(x,y) >= x) &&
        (y < PRECISION_DECIMALS() => interestRatio(x,y) <= x) &&
        (y == PRECISION_DECIMALS() => interestRatio(x,y) == x);
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

    //Replace for exact mulDiv
    //return mulDiv_mathLib(_shares,totalAssets,totalShares,_rounding == MathUpgradeable.Rounding.Up);
    
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

    //Replace for exact mulDiv
    //return mulDiv_mathLib(_assets,totalShares,totalAssets,_rounding == MathUpgradeable.Rounding.Up);
    
    return sharesMulDiv(_assets,totalShares,totalAssets,_rounding == MathUpgradeable.Rounding.Up);
}

function getDebtAmountsWithInterestCVL(uint256 _debtAssets, uint256 _rcomp) returns (uint256,uint256) {
    if (_debtAssets == 0 || _rcomp == 0) {
        return (_debtAssets, 0);
    }
    uint256 accruedInterest = interestRatio(_debtAssets, _rcomp);

    return (require_uint256(_debtAssets + accruedInterest), accruedInterest);
}

function mulDiv_mathLib(uint256 x, uint256 y, uint256 z, bool true_if_up) returns uint256 {
    if(true_if_up) return mulDivUp_mathLib(x,y,z);
    return mulDivDown_mathLib(x,y,z);
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
proof that x - roundUp(z / y) <= muldivDown(w, z, y) <= x
where w = muldivDown(x,y,z)
*/
/// Verified
rule assetsToSharesAndBackAxiom(uint256 x, uint256 y, uint256 z) {
    uint256 w = mulDivDown_mathLib(x, y, z);
    uint256 xp = mulDivDown_mathLib(w, z, y);
    mathint delta = mulDivUp_mathLib(1, z, y);

    assert xp <= x && xp + delta >= to_mathint(x);
}