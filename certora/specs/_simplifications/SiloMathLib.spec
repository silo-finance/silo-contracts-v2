methods {
    
    function SiloMathLib.convertToAssets(
        uint256 _shares,
        uint256 _totalAssets,
        uint256 _totalShares,
        Math.Rounding _rounding,
        ISilo.AssetType _assetType
    ) internal returns (uint256) =>
    sharesToAssetsApprox(_shares, _totalAssets, _totalShares, _rounding, _assetType);

    function SiloMathLib.convertToShares(
        uint256 _assets,
        uint256 _totalAssets,
        uint256 _totalShares,
        Math.Rounding _rounding,
        ISilo.AssetType _assetType
    ) internal returns (uint256) =>
    assetsToSharesApprox(_assets, _totalAssets, _totalShares, _rounding, _assetType);
    

    function SiloMathLib.getDebtAmountsWithInterest(uint256 _debtAssets, uint256 _rcomp) 
        internal returns (uint256,uint256) => getDebtAmountsWithInterestCVL(_debtAssets, _rcomp);
}

definition DECIMALS_OFFSET_POW() returns uint256 = 1;
definition PRECISION_DECIMALS() returns uint256 = 10^18;

// A restriction on the value of w = x * y / z
// The ratio between x (or y) and z is a rational number a/b or b/a.
// Important : do not set a = 0 or b = 0.
// Note: constRatio(x,y,z,a,b,w) <=> constRatio(x,y,z,b,a,w)
definition constRatio(uint256 x, uint256 y, uint256 z,
 uint256 a, uint256 b, uint256 w) 
        returns bool = 
        ( a * x == b * z && to_mathint(w) == (b * y) / a ) || 
        ( b * x == a * z && to_mathint(w) == (a * y) / b ) ||
        ( a * y == b * z && to_mathint(w) == (b * x) / a ) || 
        ( b * y == a * z && to_mathint(w) == (a * x) / b );

// Forces the (x*y/z) to behave linearly, with the specified ratios.
function discreteRatioMulDiv(uint256 x, uint256 y, uint256 z) returns uint256 
{
    uint256 res;
    require z != 0 && x*y <=max_uint256;
    // Discrete ratios:
    require( 
        (x == z && res == y) ||
        (y == z && res == x) ||
        constRatio(x, y, z, 2, 1, res) || // f = 2*x or f = x/2 (same for y)
        constRatio(x, y, z, 3, 1, res)    // f = 3*x or f = x/3 (same for y)
        );
    return res;
}

/// shares, totalAssets, totalShares, (true if round up, false if down)
/// assets, totalShares, totalAssets, (true if round up, false if down)
persistent ghost sharesMulDiv(uint256,uint256,uint256,bool) returns uint256 {       
    axiom forall uint256 x. forall uint256 y. forall uint256 z.
    /// Rounding up is equal or +1 from rounding down:
        (sharesMulDiv(x,y,z,true) == sharesMulDiv(x,y,z,false) ||
        sharesMulDiv(x,y,z,true) - sharesMulDiv(x,y,z,false) == 1) &&
    /// Multiplication symmetry:
        sharesMulDiv(x,y,z,false) == sharesMulDiv(y,x,z,false) &&
        sharesMulDiv(x,y,z,true) == sharesMulDiv(y,x,z,true) &&
    /// For shares conversion calculations, one expects 
    ///     shares <= total shares
    ///     assets <= total assets
    /// hence : x <= z => assets (shares) = x * y / z <= y = total assets (total shares)
        (sharesMulDiv(x,y,z,false) <= y) &&
    /// Nominator-denominator cancellation:
        ((x == z && z !=0) => sharesMulDiv(x,y,z,false) == y) &&
        ((y == z && z !=0) => sharesMulDiv(x,y,z,false) == x);
    /// Monotonicity:
    axiom forall uint256 x1. forall uint256 x2. forall uint256 y. forall uint256 z.
        x1 <= x2 => (
            sharesMulDiv(x1,y,z,false) <= sharesMulDiv(x2,y,z,false) &&
            sharesMulDiv(x1,y,z,true) <= sharesMulDiv(x2,y,z,true) &&
            sharesMulDiv(z,y,x1,false) >= sharesMulDiv(z,y,x2,false)
        );
    axiom forall uint256 y. forall uint256 z.
        (sharesMulDiv(0,y,z,false) == 0) && 
        (sharesMulDiv(1,y,z,false) ==0 <=> (y ==0 || y < z)) &&
        (sharesMulDiv(1,y,z,true) ==0 <=> y ==0);
    /// x*y >= (x+y)/2 (product is larger than average)
    axiom forall uint256 x. forall uint256 y. forall uint256 z.
        (x >= 1 && y >= 1 && z !=0) => 2 * sharesMulDiv(x,y,z,false) >= (x + y) / z;
    /*
    axiom forall uint256 x. forall uint256 y. forall uint256 z. forall uint256 w.
        (w == sharesMulDiv(x,y,z,false) && y !=0) => (
            sharesMulDiv(w,z,y,false) <= x && 
            sharesMulDiv(w,z,y,false) + sharesMulDiv(z,1,y,true) >= to_mathint(x));
    */
    // adding same value Q to both assets and totalAssets cannot decrease the number of shares
    axiom forall uint256 x. forall uint256 y1. forall uint256 y2. forall uint256 z. forall uint256 xQ. forall uint256 zQ.
        (x >= 1 && y1 >= 1 && y2 >= y1 && z >= 1 && xQ > x && xQ - x == zQ - z) => (
            sharesMulDiv(xQ,y2,zQ,false) >= sharesMulDiv(x,y1,z,false) &&
            sharesMulDiv(xQ,y2,zQ,true) >= sharesMulDiv(x,y1,z,true));

    // cannot give zero when it shouldn't
    axiom forall uint256 x. forall uint256 y. forall uint256 z.
        (z >= 1 && sharesMulDiv(x,y,z,false) == 0) => x * y < z * 1 &&
        ((x >= 1 && y >= 1 && z >= 1) => sharesMulDiv(x,y,z,true) >= 1);
}

/// interestRatio(_debtAssets,_rcomp) = _debtAssets * _rcomp / _PRECISION_DECIMALS;
persistent ghost interestRatio(uint256,uint256) returns uint256 {
    /// We assume a ceiling on possible debt values.
    axiom forall uint256 x. forall uint256 y. interestRatio(x,y) <= 10^50;

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

/// A copy of the Solidity implementation, with the ability to tune the mulDiv approx.
function sharesToAssetsApprox(
    uint256 _shares,
    uint256 _totalAssets,
    uint256 _totalShares,
    Math.Rounding _rounding,
    ISilo.AssetType _assetType
 ) returns uint256 {
    uint256 totalShares = _assetType == ISilo.AssetType.Debt ?
        _totalShares : require_uint256(_totalShares + DECIMALS_OFFSET_POW());
    uint256 totalAssets = _assetType == ISilo.AssetType.Debt ?
        _totalAssets : require_uint256(_totalAssets + 1);

    if (totalShares == 0 || totalAssets == 0) return _shares;

    //Replace for exact mulDiv
    //return mulDiv_mathLib(_shares,totalAssets,totalShares,_rounding == Math.Rounding.Ceil);  //exact
    return sharesMulDiv(_shares,totalAssets,totalShares,_rounding == Math.Rounding.Ceil);  //summ
    //return discreteRatioMulDiv(_shares, totalAssets, totalShares); // under-approx (rarely used)
}

/// A copy of the Solidity implementation, with the ability to tune the mulDiv approx.
function assetsToSharesApprox(
    uint256 _assets,
    uint256 _totalAssets,
    uint256 _totalShares,
    Math.Rounding _rounding,
    ISilo.AssetType _assetType
) returns uint256 {
    uint256 totalShares = _assetType == ISilo.AssetType.Debt ?
        _totalShares : require_uint256(_totalShares + DECIMALS_OFFSET_POW());
    uint256 totalAssets = _assetType == ISilo.AssetType.Debt ?
        _totalAssets : require_uint256(_totalAssets + 1);

    if (totalShares == 0 || totalAssets == 0) return _assets;

    //Replace for exact mulDiv
    //return mulDiv_mathLib(_assets,totalShares,totalAssets,_rounding == Math.Rounding.Ceil);  //exact
    return sharesMulDiv(_assets,totalShares,totalAssets,_rounding == Math.Rounding.Ceil);  //summ
    //return discreteRatioMulDiv(_assets, totalAssets, totalShares); // under-approx (rarely used)
}

/// A copy of the Solidity implementation, 
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
    assert (x == 1) => (resUp == 0 <=> y ==0);
    assert (x >= 1 && y >= 1 && z !=0) => to_mathint(resDown) >= (x + y) / (2 * z);
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