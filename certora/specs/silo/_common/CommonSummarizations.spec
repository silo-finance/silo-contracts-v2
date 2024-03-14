methods {
    // applies only to EVM calls
    function _.accrueInterest() external => DISPATCHER(true); // silo
    function _.initialize(address,address) external => DISPATCHER(true); // silo
    function _.withdrawCollateralsToLiquidator(uint256,uint256,address,address,bool) external => DISPATCHER(true); // silo
    function _.beforeQuote(address) external => NONDET;
    function _.connect(address) external => NONDET; // IRM
    function _.onLeverage(address,address,address,uint256,bytes) external => NONDET; // leverage receiver
    function _.onFlashLoan(address,address,uint256,uint256,bytes) external => NONDET; // flash loan receiver
    function _.getFeeReceivers(address) external => CONSTANT; // factory
    function _._afterTokenTransfer(address,address,uint256) internal => CONSTANT; // shares tokens
    //function _.mulDiv(uint256 x, uint256 y, uint256 denominator) internal => cvlMulDiv(x,y,denominator) expect uint256;
    function _.mulDiv(uint256 x, uint256 y, uint256 denominator) internal => mulDivLIA(x,y,denominator) expect uint256;
}

function cvlMulDiv(uint256 x, uint256 y, uint256 denominator) returns uint {
    require denominator != 0;
    return require_uint256(x * y / denominator);
}

persistent ghost mapping(uint256 => mapping(uint256 => uint256)) _mulDivGhost {
    /// Monotonically increasing
    axiom forall uint256 xy1. forall uint256 xy2. forall uint256 z.
        xy1 <= xy2 => _mulDivGhost[xy1][z] <= _mulDivGhost[xy2][z];
    /// Monotonically decreasing
    axiom forall uint256 xy. forall uint256 z1. forall uint256 z2.
        z1 <= z2 => _mulDivGhost[xy][z1] >= _mulDivGhost[xy][z2];
}

function mulDivLIA(uint256 x, uint256 y, uint256 z) returns uint256 {
    require z !=0;
    uint256 xy = require_uint256(x * y);
    /*if(z > x) {
        uint256 w = assert_uint256(z - x);
        uint256 wy = require_uint256(w * y); 
        /// [(x * y) / z] + [(z - x) * y / z] = y
        /// muldiv(x , y , z) + muldiv((z-x) , y , z) <= y
        require _mulDivGhost[xy][z] + _mulDivGhost[wy][z] <= to_mathint(y);
    }*/
    require _mulDivGhost[xy][z] <= xy;   
    require xy < z => _mulDivGhost[xy][z] == 0;
    require xy == z => _mulDivGhost[xy][z] == 1;
    require y <= z => _mulDivGhost[xy][z] <= x;
    require x <= z => _mulDivGhost[xy][z] <= y;
    require y == z => _mulDivGhost[xy][z] == x;
    require x == z => _mulDivGhost[xy][z] == y;
    return _mulDivGhost[xy][z];
}


