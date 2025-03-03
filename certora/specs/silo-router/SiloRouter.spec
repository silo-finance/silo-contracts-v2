using SiloRouterHarness as SiloRouterHarness;

use builtin rule sanity filtered { f -> 
    f.contract == SiloRouterHarness && f.selector != sig:multicall(bytes[]).selector
}

rule consistencyOfPausing(env e1, env e2)
{
    bytes[] data;
    pause(e1);  // this didn't revert
    multicall@withrevert(e2, data);
    bool reverted = lastReverted;
    assert reverted;    
    satisfy true;
}

rule onlyOwnerCanPause(env e1, env e2)
{
    storage init = lastStorage;
    pause(e1);  // didn't revert, e1.msg.sender is the owner

    pause@withrevert(e2) at init;
    bool reverted2 = lastReverted;

    assert e1.msg.sender != e2.msg.sender => reverted2; // must revert for all other callers
    satisfy true;
}

rule onlyOwnerCanUnpause(env e1, env e2)
{
    storage init = lastStorage;
    unpause(e1);  // didn't revert, e1.msg.sender is the owner

    unpause@withrevert(e2) at init;
    bool reverted2 = lastReverted;

    assert e1.msg.sender != e2.msg.sender => reverted2; // must revert for all other callers
    satisfy true;
}