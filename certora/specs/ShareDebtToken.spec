
methods {
    /// functions that are not dependent on the enviroment 
    function allowance(address,address) external returns(uint) envfree;
    function receiveAllowance(address,address) external returns(uint) envfree;
    function balanceOf(address)         external returns(uint) envfree;
    function totalSupply()              external returns(uint) envfree;
}

// certoraRun certora/confs/silo-core/share_debt_token_sanity.conf 
// certoraRun certora/confs/silo-core/share_debt.conf
/// @title Transfer is possible`
rule transferIsNotPossibleWithoutReverseApproval(method f) filtered { f -> !f.isView } {
    address recipient;

    env e;

    // we don't want recipient to do any action
    require e.msg.sender != recipient;
    // silo can mint or force transfer, so we need to exclude it
    require e.msg.sender != currentContract.silo;
    // we assuming recipient did not allow sender to send debt
    require receiveAllowance(e.msg.sender, recipient) == 0;

    uint256 recipientBalanceBefore = balanceOf(recipient);

    calldataarg args;
    f(e, args);

    // recipient should not receive any debt tokens
    assert balanceOf(recipient) == recipientBalanceBefore;
}
