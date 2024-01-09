
methods {
    /// functions that are not dependent on the enviroment 
    function allowance(address,address) external returns(uint) envfree;
    function receiveAllowance(address,address) external returns(uint) envfree;
    function balanceOf(address)         external returns(uint) envfree;
    function totalSupply()              external returns(uint) envfree;

    // function forwardTransfer(address _owner, address _recipient, uint256 _amount) external;
    // function forwardTransferFrom(address _spender, address _from, address _to, uint256 _amount);
    // function forwardApprove(address _owner, address _spender, uint256 _amount) public;
}

// certoraRun certora/confs/silo-core/share_debt_token_sanity.conf 
/// @title Transfer is possible`
rule transferIsNotPossibleWithoutReverseApproval(method f) {
    address recipient;

    env e;

    require e.msg.sender != recipient;
    require balanceOf(recipient) == 0;
    require receiveAllowance(e.msg.sender, recipient) == 0;

    calldataarg args;
    f(e, args);

    uint256 balance_sender_before = balanceOf(sender);

    assert balanceOf(recipient) == 0;
}
