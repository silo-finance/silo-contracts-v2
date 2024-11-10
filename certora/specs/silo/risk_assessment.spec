/**
@title Reentrancy properties
**/

import "../summaries/two_silos_summaries.spec";
import "../summaries/siloconfig_dispatchers.spec";
import "../summaries/tokens_dispatchers.spec";
import "../summaries/safe-approximations.spec";

import "../requirements/tokens_requirements.spec";

using SiloConfig as siloConfig;
using Silo0 as silo0;
using Silo1 as silo1;

using ShareDebtToken0 as shareDebtToken0;
using ShareProtectedCollateralToken0 as shareProtectedCollateralToken0;
using ShareDebtToken1 as shareDebtToken1;
using ShareProtectedCollateralToken1 as shareProtectedCollateralToken1;
using Token0 as token0;
using Token1 as token1;
using EmptyHookReceiver as hookReceiver;


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

    function siloConfig.reentrancyGuardEntered() external returns (bool)  envfree;


    // move to setup

    function Silo0.silo() external returns (address) => silo0;
    function ShareDebtToken0.silo() external returns (address) => silo0;
    function ShareProtectedCollateralToken0.silo() external returns (address) => silo0;
    //function Silo0._getSilo() internal returns (address) => silo0;
    

    function Silo1.silo() external returns (address) => silo1;
    function ShareDebtToken1.silo() external returns (address) => silo1;
    function ShareProtectedCollateralToken1.silo() external returns (address) => silo1;
    //function ShareToken._getSilo() internal  => cvlGetSilo(calledContract) expect (ShareToken.ISilo);
    /*
    got: ShareToken.ISilo is not a valid EVM type
    */
    //function ShareToken._getSilo() internal  => cvlGetSilo(calledContract) expect (address);
    /* got: Bad internal method returns: Cannot merge "ShareToken._getSilo() returns (Contract ISilo)" and "ShareToken._getSilo()" - they have incompatible return values: Different arities (1 vs 0) */
    function _._getSiloConfig() internal  => siloConfig expect (address);
    function _._getSilo() internal  => cvlGetSilo(calledContract)  expect (address);
    function _.siloConfig() internal  => siloConfig expect (address);
    function _.siloConfig() external   => siloConfig expect (address);

    function _.getDebtShareTokenAndAsset(
        address _silo
    ) external => CVLGetDebtShareTokenAndAsset(_silo) expect (address, address);
    

}

/// @title Early summarization - for speed up
/// @notice In this setup we assume that `silo0` was the input to this function
function CVLGetDebtShareTokenAndAsset(address _silo) returns (address, address) {
    if(_silo == silo0)
        return (shareDebtToken0, token0);
    else
        return (shareDebtToken1, token1);
}




// ---- Reentrancy Rules ----

function cvlGetSilo(address called) returns address {
    if (called == silo1 || called == shareDebtToken1 || called == shareProtectedCollateralToken1 ) 
        return silo1;
    else
        return silo0;
}


definition NOT_ENTERED() returns uint256 = 0; 
definition ENTERED() returns uint256 = 1; 
definition REENTRANT_FLAG_SLOT returns uint256 = 0; 

ghost bool reentrantStatusMovedToTrue;
ghost bool reentrantStatusLoaded; 
ghost bool unsafeExternalCall; 

//update movedToTrue, stays true or become true when _crossReentrantStatus is entered 
hook ALL_TSTORE(uint loc, uint v) {
    reentrantStatusMovedToTrue =  reentrantStatusMovedToTrue || ( loc == REENTRANT_FLAG_SLOT() && v == ENTERED())  ; 
}


hook ALL_TLOAD(uint loc) uint v {
    reentrantStatusLoaded =  reentrantStatusLoaded || loc == REENTRANT_FLAG_SLOT();
}


// We are hooking here on "CALL" opcodes in order to capture if there was a storage access before or/and after a call
hook CALL(uint g, address addr, uint value, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    unsafeExternalCall = unsafeExternalCall || !siloContracts(addr);
}

hook DELEGATECALL(uint g, address addr, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    unsafeExternalCall = true;
}

definition onlySiloContractsMethods(method f) returns bool =
    ( (f.contract == shareDebtToken0 || f.contract == shareDebtToken1 ||
        (f.contract == shareProtectedCollateralToken0 || f.contract == shareProtectedCollateralToken1) ||
        f.contract == silo0 || f.contract == silo1) &&
        (   f.selector == sig:shareDebtToken0.synchronizeHooks(uint24,uint24).selector ||
            f.selector == sig:shareDebtToken0.burn(address,address,uint256).selector ||
            f.selector == sig:shareDebtToken0.forwardTransferFromNoChecks(address,address,uint256).selector ||
            f.selector == sig:shareDebtToken0.mint(address,address,uint256).selector 
        )
    )
    ||
    (  f.contract ==  siloConfig &&
        (   f.selector == sig:onDebtTransfer(address,address).selector ||
            f.selector == sig:turnOnReentrancyProtection().selector ||
            f.selector == sig:turnOffReentrancyProtection().selector ||
            f.selector == sig:setOtherSiloAsCollateralSilo(address).selector ||
            f.selector == sig:setThisSiloAsCollateralSilo(address).selector
        )
     )
     ;

definition siloContracts(address c) returns bool = 
        c == silo0 || c == silo1 ||
        c == shareDebtToken0 || c == shareProtectedCollateralToken0 ||
        c == shareDebtToken1 || c == shareProtectedCollateralToken1 ||
        c == hookReceiver ||
        c == siloConfig._INTEREST_RATE_MODEL0 ||
        c == siloConfig._INTEREST_RATE_MODEL1 ; 

rule onlyTrustedSender(method f) filtered { f -> onlySiloContractsMethods(f) } {
    env e;
    require !reentrantStatusLoaded; 
    require !unsafeExternalCall;
    requireInvariant RA_reentrancyGuardStaysUnlocked();
    configForEightTokensSetupRequirements();
    nonSceneAddressRequirements(e.msg.sender);
    silosTimestampSetupRequirements(e);
    calldataarg args;
    f@withrevert(e,args);
    assert !lastReverted => (siloContracts(e.msg.sender));

}


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



rule RA_whoMustLoadCrossNonReentrant(method f) filtered {f-> !onlySiloContractsMethods(f) && !f.isView}{
    env e;
    require !reentrantStatusLoaded; 
    require !unsafeExternalCall;
    requireInvariant RA_reentrancyGuardStaysUnlocked();
    configForEightTokensSetupRequirements();
    nonSceneAddressRequirements(e.msg.sender);
    silosTimestampSetupRequirements(e);
    bool valueBefore = siloConfig.reentrancyGuardEntered();
    //require e.msg.sender != siloConfig._HOOK_RECEIVER;
    calldataarg args;
    f(e,args);
    assert reentrantStatusLoaded ; 
    assert !valueBefore;
} 

rule RA_reentrancyGuardStatusChanged(method f) 
        filtered {f-> !f.isView && !onlySiloContractsMethods(f) 
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
    //require e.msg.sender != siloConfig._HOOK_RECEIVER;
    calldataarg args;
    f(e,args);
    assert reentrantStatusMovedToTrue || !unsafeExternalCall;
}


rule check_sanity(method f) 
    
{
    // setup requirements 
    env e;
    configForEightTokensSetupRequirements();
    nonSceneAddressRequirements(e.msg.sender);
    silosTimestampSetupRequirements(e);

    calldataarg args;
    f(e,args);
    satisfy true;
}
