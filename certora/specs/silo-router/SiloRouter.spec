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

rule onlyOwnerCanPause(env e)
{
    pause(e);
    assert e.msg.sender == owner(e);
}

rule onlyOwnerCanUnpause(env e)
{
    unpause(e);
    assert e.msg.sender == owner(e);
}