/* Integrity of main methods */

// import "../requirements/CompleteSiloSetup.spec";
import "authorized_functions.spec";
import "unresolved.spec";
import "../_simplifications/SiloMathLib.spec";
import "../_simplifications/Oracle_quote_one.spec";
import "../_simplifications/SimplifiedGetCompoundInterestRateAndUpdate.spec";

methods {

}

// debt in two silos is impossible - rule
rule noDebtInBothSilos_asRule(env e, address user, method f)
    filtered { f -> !filterOutInInvariants(f) && !onlySiloContractsMethods(f) }
{   
    SafeAssumptions_withInvariants_forMethod(e, user, f);
    bool hasDebt0Before = shareDebtToken0.balanceOf(user) != 0;
    bool hasDebt1Before = shareDebtToken1.balanceOf(user) != 0;

    calldataarg args;
    f(e, args);

    bool hasDebt0After = shareDebtToken0.balanceOf(user) != 0;
    bool hasDebt1After = shareDebtToken1.balanceOf(user) != 0;

    assert !(hasDebt0Before && hasDebt1Before)
        => !(hasDebt0After && hasDebt1After);
}
