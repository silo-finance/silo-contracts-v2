methods {
    // applies only to EVM calls
    function _.accrueInterest() external => DISPATCHER(true); // silo
    function _.initialize(address,address) external => DISPATCHER(true); // silo
    function _.withdrawCollateralsToLiquidator(uint256,uint256,address,address,bool) external => DISPATCHER(true); // silo
    function _.beforeQuote(address) external => NONDET;
    function _.connect(address) external => NONDET; // IRM
    function _.afterTokenTransfer(address,uint256,address,uint256,uint256,uint256) external => ALWAYS(true); // Hook Reveiver
}
