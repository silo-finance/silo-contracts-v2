methods {
    function _.mulDiv(uint x, uint y, uint denominator) internal => cvlMulDiv(x,y,denominator) expect uint;
}


function cvlMulDiv(uint x, uint y, uint denominator) returns uint {
    require(denominator != 0);
    return require_uint256(x*y/denominator);
}
