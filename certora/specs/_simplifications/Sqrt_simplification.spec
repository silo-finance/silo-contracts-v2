methods {
    function MathUpgradeable.sqrt(uint256 y) internal returns (uint256) => floorSqrt(y);
}

// A precise summarization of sqrt
ghost floorSqrt(uint256) returns uint256 {    
    // sqrt(x)^2 <= x
    axiom forall uint256 x. floorSqrt(x)*floorSqrt(x) <= to_mathint(x) && 
        // sqrt(x+1)^2 > x 
        (floorSqrt(x) + 1)*(floorSqrt(x) + 1) > to_mathint(x);
}
