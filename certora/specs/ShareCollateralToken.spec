
methods {
    /// functions that are not dependent on the enviroment 
    function allowance(address,address) external returns(uint) envfree;
    function balanceOf(address)         external returns(uint) envfree;
    function totalSupply()              external returns(uint) envfree;
}

/// @title Transfer must move `amount` tokens from the caller's account to `recipient`
rule transferSpec() {
    address sender; address recipient; uint amount;

    env e;
    require e.msg.sender == sender;

    mathint balance_sender_before = balanceOf(sender);
    mathint balance_recipient_before = balanceOf(recipient);

    transfer(e, recipient, amount);

    mathint balance_sender_after = balanceOf(sender);
    mathint balance_recipient_after = balanceOf(recipient);

    assert balance_sender_after == balance_sender_before - amount,
        "transfer must decrease sender's balance by amount";

    assert balance_recipient_after == balance_recipient_before + amount,
        "transfer must increase recipient's balance by amount";
}
