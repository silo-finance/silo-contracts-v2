import "SiloMethods.spec";
// Hooks to call of accruedInterest. Logs whether the method was called or not.
// Only for single-silo setup.

methods 
{
    function Silo._accrueInterest() internal 
        returns (uint256, ISiloConfig.ConfigData memory) with (env e) => accrueInterestSummary(e);
    function Silo0._accrueInterest_orig() external 
        returns (uint256, ISiloConfig.ConfigData memory);
}

ghost bool wasAccrueInterestCalled_silo0 
{
    init_state axiom wasAccrueInterestCalled_silo0 == false;
}

function accrueInterestSummary(env e) 
    returns (uint256, ISiloConfig.ConfigData)
{
    wasAccrueInterestCalled_silo0 = true;
    uint256 interest;
    ISiloConfig.ConfigData config;
    interest, config = silo0._accrueInterest_orig(e);
    return (interest, config);
}

