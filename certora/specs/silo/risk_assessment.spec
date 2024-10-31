/**
@title Reentrancy properties
**/

import "../summaries/two_silos_summaries.spec";
import "../summaries/siloconfig_dispatchers.spec";
import "../summaries/tokens_dispatchers.spec";
import "../summaries/safe-approximations.spec";

import "../requirements/tokens_requirements.spec";

using SiloConfig as siloConfig;
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


    // Unresolved calls 
     function _.onFlashLoan(address _initiator, address _token, uint256 _amount, uint256 _fee, bytes  _data) external => NONDET;
     unresolved external in Silo0.callOnBehalfOfSilo(address,uint256,uint8,bytes) => DISPATCH(use_fallback=true) [
        
    ] default NONDET;


}

// ---- Reentrancy Rules ----



definition NOT_ENTERED() returns uint256 = 1; 
definition ENTERED() returns uint256 = 2; 

ghost bool reentrantStatusMovedToTrue;
ghost bool reentrantStatusLoaded; 

//update movedToTrue, stays true or become true when _crossReentrantStatus is entered 
hook Sstore siloConfig._crossReentrantStatus uint256 new_value (uint old_value) {
    reentrantStatusMovedToTrue =  reentrantStatusMovedToTrue || (new_value == ENTERED())  && old_value == NOT_ENTERED(); 
}

hook Sload uint256 value  siloConfig._crossReentrantStatus {
    reentrantStatusLoaded =  true;
}

/// @title Accruing interest in Silo0 (in the same block) should not change any borrower's LtV.
invariant RA_reentrancyGuardStaysUnlocked()
    siloConfig._crossReentrantStatus == NOT_ENTERED()
    { preserved with (env e) 
        { 
            configForEightTokensSetupRequirements();
            nonSceneAddressRequirements(e.msg.sender);
            silosTimestampSetupRequirements(e);
            require e.msg.sender != siloConfig._HOOK_RECEIVER;
        } 
}


rule RA_whoMustLoadCrossNonReentrant(method f) filtered {f-> !f.isView}{
    env e;
    require !reentrantStatusLoaded; 
    requireInvariant RA_reentrancyGuardStaysUnlocked();
    configForEightTokensSetupRequirements();
    nonSceneAddressRequirements(e.msg.sender);
    silosTimestampSetupRequirements(e);
    require e.msg.sender != siloConfig._HOOK_RECEIVER;
    calldataarg args;
    f(e,args);
    assert reentrantStatusLoaded; 
} 

rule RA_reentrancyGuardStatusChanged(method f) filtered {f-> !f.isView}{
    // setup requirements 
    env e;
    configForEightTokensSetupRequirements();
    nonSceneAddressRequirements(e.msg.sender);
    silosTimestampSetupRequirements(e);

    // precondition : ghost is false and starting with unlocked state
    uint256 valueBefore = siloConfig._crossReentrantStatus;
    require !reentrantStatusMovedToTrue; 
    requireInvariant RA_reentrancyGuardStaysUnlocked();
    require e.msg.sender != siloConfig._HOOK_RECEIVER;
    calldataarg args;
    f(e,args);
    assert reentrantStatusMovedToTrue; 
    assert valueBefore == NOT_ENTERED();
}