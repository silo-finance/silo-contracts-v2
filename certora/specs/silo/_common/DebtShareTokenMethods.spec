methods {
    /// functions that are not dependent on the enviroment
    function allowance(address,address) external returns(uint) envfree;
    function receiveAllowance(address,address) external returns(uint) envfree;
    function balanceOf(address) external returns(uint) envfree;
    function totalSupply() external returns(uint) envfree;
}
