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
    function _.mulDiv(uint256 x, uint256 y, uint256 denominator) internal => cvlMulDiv(x,y,denominator) expect uint256;
    function _.getCompoundInterestRate(address,uint256) external => CONSTANT; // IRM
}

function cvlMulDiv(uint256 x, uint256 y, uint256 denominator) returns uint {
    require(denominator != 0);
    return require_uint256(x * y / denominator);
}
