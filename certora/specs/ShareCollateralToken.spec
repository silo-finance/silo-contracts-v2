
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


rule noDecreaseByOther(method f, address account) filtered { f -> !f.isView } {
    env e;

    require e.msg.sender != account;
    uint256 allowance = allowance(account, e.msg.sender); 
    requireInvariant sumOfBalancesInvariant();
    require balanceOf(account) + balanceOf(e.msg.sender) <= to_mathint(totalSupply()); //todo - prove this! 

    
    uint256 before = balanceOf(account);
    calldataarg args;
    f(e,args); /* check on all possible arguments */
    uint256 after = balanceOf(account);
    /* logic implication : true when: (a) the left hand side is false or (b) right hand side is true  */
    assert after < before =>  (e.msg.sender == account  ||  to_mathint(allowance) >= (before-after) || 
    (e.msg.sender == currentContract.silo && f.selector== sig:burn(address,address,uint256).selector))  ;
    
}



invariant balanceOfZero()  
    balanceOf(0) == 0 ;

/*
invariant singleBalance() 
    forall address u. balanceOf(u) <= totalSupply(); 
*/

ghost mathint sumOfBalances {
     init_state axiom sumOfBalances == 0; 
}
/* old_value := balance[user]
balance[user] := new_value 
sumOfBalances =  sumOfBalances +  new_value - old_value  */

hook Sstore _balances[KEY address user] uint256 newValue (uint256 oldValue) STORAGE {
    sumOfBalances = sumOfBalances + newValue - oldValue;
}

hook Sload uint256 value _balances[KEY address user] STORAGE {
    require to_mathint(value) <= sumOfBalances;
}

invariant sumOfBalancesInvariant() 
        sumOfBalances == to_mathint(totalSupply()); 

