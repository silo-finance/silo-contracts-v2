/*
Reentrancy properties:
Reentrancy protection is shared among the different Silo contracts that interacts, the following are properties of this unique reentrancy guard:
1. Guard must be set to false after every public call. A public call is a call that can be made by a non-silo-contract 
2. Guard must be turned on for functions that have untrusted external call. An untrusted external call is to call to a non-silo-contract
3. Guard must be checked on all public functions 
*/

import "./../setup/meta/authorized_functions.spec";


methods {
    // ---- `IInterestRateModel` -----------------------------------------------
    // Since `getCompoundInterestRateAndUpdate` is not view, this is not strictly sound.
    function _.getCompoundInterestRateAndUpdate(
        uint256 _collateralAssets,
        uint256 _debtAssets,
        uint256 _interestRateTimestamp
    ) external => NONDET;

    // ---- `ISiloOracle` ------------------------------------------------------
    // NOTE: Since `beforeQuote` is not a view function, strictly speaking this is unsound.
    function _.beforeQuote(address) external => NONDET DELETE;
    function _.synchronizeHooks(uint24,uint24) external => NONDET;


    // Unresolved calls are assumed to be nondet 
     function _.onFlashLoan(address _initiator, address _token, uint256 _amount, uint256 _fee, bytes  _data) external => NONDET;
     unresolved external in Silo0.callOnBehalfOfSilo(address,uint256,uint8,bytes) => DISPATCH(use_fallback=true) [
        
    ] default NONDET;

    function siloConfig.reentrancyGuardEntered() external returns (bool)  envfree;

}


definition NOT_ENTERED() returns uint256 = 0; 
definition ENTERED() returns uint256 = 1; 
definition REENTRANT_FLAG_SLOT returns uint256 = 0; 

//--- flags to track execution trace:
ghost bool reentrantStatusMovedToTrue;
ghost bool reentrantStatusLoaded; 
ghost bool unsafeExternalCall; 

/* update ghost reentrantStatusMovedToTrue on store to reentrant slot,
 stays true or become true when _crossReentrantStatus is entered */
hook ALL_TSTORE(uint loc, uint v) {
    reentrantStatusMovedToTrue =  loc == 0 && (reentrantStatusMovedToTrue || ( loc == REENTRANT_FLAG_SLOT() && v == ENTERED()))  ; 
}

// update ghost reentrantStatusMovedToTrue, stays true or become true when _crossReentrantStatus is loaded 
hook ALL_TLOAD(uint loc) uint v {
    reentrantStatusLoaded =  loc == 0 && (reentrantStatusLoaded || loc == REENTRANT_FLAG_SLOT());
}


// checking if a call/delegate-call is a "safe" one or while reentrant is entered
hook CALL(uint g, address addr, uint value, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {

    unsafeExternalCall = unsafeExternalCall || 
                        (!siloContracts(addr) && !reentrantStatusMovedToTrue);
}
hook DELEGATECALL(uint g, address addr, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    unsafeExternalCall = unsafeExternalCall || 
                        (!siloContracts(addr) && !reentrantStatusMovedToTrue);
}

/**
@title Every public method leave the reentrancy guard off
*/
invariant RA_reentrancyGuardStaysUnlocked()
    !siloConfig.reentrancyGuardEntered()
    filtered { f -> !onlySiloContractsMethods(f) }
    { preserved with (env e) 
        { 
            configForEightTokensSetupRequirements();
            nonSceneAddressRequirements(e.msg.sender);
            silosTimestampSetupRequirements(e);
            require e.msg.sender != siloConfig._HOOK_RECEIVER;
        } 
}

/**
@title Every public method checks (loads) the reentrancy guard
*/
rule RA_reentrancyGuardChecked(method f) filtered {f-> !onlySiloContractsMethods(f) && !f.isView}{
    env e;
    require !reentrantStatusLoaded; 
    require !unsafeExternalCall;
    requireInvariant RA_reentrancyGuardStaysUnlocked();
    configForEightTokensSetupRequirements();
    nonSceneAddressRequirements(e.msg.sender);
    silosTimestampSetupRequirements(e);
    calldataarg args;
    f(e,args);
    assert reentrantStatusLoaded ; 
} 

/**
@title Every public method that has an unsafe call turns the reentrancy guard on
*/
rule RA_reentrancyGuardStatusChanged(method f) 
        filtered {f-> !f.isView && !onlySiloContractsMethods(f) 
                    // functions that are approved to not turn on reentrancy
                    && f.selector != sig:silo0.callOnBehalfOfSilo(address,uint256,ISilo.CallType,bytes).selector 
                    && f.selector != sig:silo0.flashLoan(address,address,uint256,bytes).selector 
                    // todo: once the code is fixed remove this 
                    && f.selector != sig:silo0.withdrawFees().selector 
}
{
    // setup requirements 
    env e;
    configForEightTokensSetupRequirements();
    nonSceneAddressRequirements(e.msg.sender);
    silosTimestampSetupRequirements(e);

    // precondition : ghost is false and starting with unlocked state    
    require !reentrantStatusMovedToTrue; 
    require !unsafeExternalCall;
    requireInvariant RA_reentrancyGuardStaysUnlocked();
    calldataarg args;
    f(e,args);
    assert !unsafeExternalCall;
}



