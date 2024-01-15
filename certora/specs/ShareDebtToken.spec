
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

    uint256 recipientBalanceBefore = balanceOf(recipient);

    if (f.selector == sig:transferFrom(address, address, uint256).selector) {
        address from;
        uint256 amount;
        // when transfering from, all we care that recipient did not allow for transfer from owner
        require receiveAllowance(from, recipient) == 0;
        transferFrom(e, from, recipient, amount);
    } else {
        require receiveAllowance(e.msg.sender, recipient) == 0;

        calldataarg args;
        f(e, args);
    }

    // recipient should not receive any debt tokens
    assert balanceOf(recipient) == recipientBalanceBefore;
}
