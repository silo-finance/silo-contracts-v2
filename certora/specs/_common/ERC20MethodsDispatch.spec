// ERC20 methods
methods {
    function _.name() external => PER_CALLEE_CONSTANT DELETE;
    function _.symbol() external => PER_CALLEE_CONSTANT DELETE;
    function _.decimals() external => DISPATCHER(true);
    function _.totalSupply() external => DISPATCHER(true);
    function _.balanceOf(address) external => DISPATCHER(true);
    function _.allowance(address,address) external => DISPATCHER(true);
    function _.approve(address,uint256) external => DISPATCHER(true);
    //function _.mint(address,uint256) external => DISPATCHER(true);
    function _.mint(address,address,uint256) external => DISPATCHER(true);
    //function _.burn(address,uint256) external => DISPATCHER(true);
    function _.burn(address,address,uint256) external => DISPATCHER(true);
    function _.transfer(address,uint256) external => DISPATCHER(true);
    function _.transferFrom(address,address,uint256) external => DISPATCHER(true);

    // for IShareToken
    function _.balanceOfAndTotalSupply(address) external => DISPATCHER(true);
    function _.synchronizeHooks(uint24, uint24) external => DISPATCHER(true);

    // for PartialLiuidation
    function _.synchronizeHooks(address, uint24, uint24) external => PER_CALLEE_CONSTANT DELETE;
    //function _.synchronizeHooks(address, uint24, uint24) external => DISPATCHER(true);
}