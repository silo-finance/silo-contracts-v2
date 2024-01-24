methods {
    // applies only to EVM calls
    function _.accrueInterest() external => DISPATCHER(true); // silo
    function _.initialize(address,address) external => DISPATCHER(true); // silo
    function _.getDebtAssets() external => NONDET; // silo
    function _.getCollateralAndProtectedAssets() external => NONDET; // silo
    function _.withdrawCollateralsToLiquidator(uint256,uint256,address,address,bool) external => DISPATCHER(true); // silo
    function _.beforeQuote(address) external => NONDET;
    function _.connect(address) external => NONDET; // IRM
    function _.onLeverage(address,address,address,uint256,bytes) external => NONDET; // leverage receiver
    function _.onFlashLoan(address,address,uint256,uint256,bytes) external => NONDET; // flash loan receiver
    function _.getFeeReceivers(address) external => CONSTANT; // factory
    function _.getConfig(address) external => CONSTANT; // config
}
