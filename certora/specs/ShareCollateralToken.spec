
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
    
    require balance_sender_before + balance_recipient_before <= to_mathint(totalSupply()); //todo - prove this! 

    transfer(e, recipient, amount);

    mathint balance_sender_after = balanceOf(sender);
    mathint balance_recipient_after = balanceOf(recipient);
    
    assert sender != recipient => balance_sender_after == balance_sender_before - amount,
                "transfer must decrease sender's balance by amount";

    assert sender != recipient => balance_recipient_after == balance_recipient_before + amount,
                "transfer must increase recipient's balance by amount";

    assert sender == recipient => balance_recipient_after == balance_recipient_before,
                "stays the same on to==from";
    
}


/// @title Transfer is possible`
rule transferIsPossible() {
    address sender; address recipient; uint amount;

    env e;
    require e.msg.sender == sender;

    uint256 balance_sender_before = balanceOf(sender);

    transfer(e, recipient, amount);

    satisfy amount == balance_sender_before;
}

rule transferShouldRevert() {
    address sender; address recipient; uint amount;

    env e;
    require e.msg.sender == sender;

    uint256 balance_sender_before = balanceOf(sender);

    transfer@withrevert(e, recipient, amount);
    bool reverted = lastReverted; 

    assert balance_sender_before < amount => reverted;

}


/// @title Order of operations: transfer A ; transfer B ~ transfer B ; transfer A 
rule transferOrder() {
    
    
    calldataarg args1;
    calldataarg args2;
    env e;

    

    storage initialState = lastStorage;

    transfer(e, args1);
    transfer(e, args2);
    storage optionOneState = lastStorage;

    transfer@withrevert(e, args2) at initialState;
    bool revert2 = lastReverted;
    transfer@withrevert(e, args1);
    bool revert1 = lastReverted;

    storage optionTwoState = lastStorage;
    assert !revert2 && !revert1; 
    assert optionTwoState == optionOneState;

}
