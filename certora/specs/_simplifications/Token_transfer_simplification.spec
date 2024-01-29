// this simplification will speed up execution, 
// eg rule `VC_Silo_siloData_management` was executed in 47min with this simplification and in 65min without
methods {
    function Token0.transferFrom(address from, address to, uint256 amount)
        external
        returns (bool) => NONDET;

    function Token0.transfer(address to, uint256 amount)
        external
        returns (bool) => NONDET;
}
