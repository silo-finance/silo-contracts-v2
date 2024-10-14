/* Tokens dispatcher summaries
 *
 * NOTE: this spec assumes that `Silo0` and `Silo1` are the collateral share tokens.
 */

 methods {
    // The functions `name` and `symbol` are deleted since they cause memory partitioning
    // problems.
    function _.name() external => PER_CALLEE_CONSTANT DELETE;
    function _.symbol() external => PER_CALLEE_CONSTANT DELETE;

    // ---- Dispatcher ---------------------------------------------------------
    // Using `DISPATCHER` for calls like `IShareToken(debtShareToken).balanceOf(borrower)`
    function _.decimals() external => DISPATCHER(true);
    function _.totalSupply() external => DISPATCHER(true);
    function _.balanceOf(address) external => DISPATCHER(true);
    function _.allowance(address,address) external => DISPATCHER(true);
    function _.approve(address,uint256) external => DISPATCHER(true);
    function _.mint(address,address,uint256) external => DISPATCHER(true);
    function _.burn(address,address,uint256) external => DISPATCHER(true);
    function _.transfer(address,uint256) external => DISPATCHER(true);
    function _.transferFrom(address,address,uint256) external => DISPATCHER(true);

    // `IShareToken`
    function _.balanceOfAndTotalSupply(address) external => DISPATCHER(true);
}
