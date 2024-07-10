import "../_common/CompleteSiloSetup.spec";
import "../_common/IsSiloFunction.spec";
import "../_common/SiloMethods.spec";
import "../_common/Helpers.spec";
import "../_common/CommonSummarizations.spec";
import "../_simplifications/Oracle_quote_one.spec";
//import "../_simplifications/priceOracle.spec";
//import "../_simplifications/Silo_isSolvent_ghost.spec";
import "../_simplifications/SiloSolvencyLib.spec";
import "../_simplifications/SimplifiedGetCompoundInterestRateAndUpdate.spec";

// these rules are in development


// not sure how to call liquidationCall() now
// rule remainsSolventAfterSelfLiquidation(env e, address user)
// {
//     completeSiloSetupEnv(e);
//     completeSiloSetupAddress(user);
//     totalSupplyMoreThanBalance(user);
//     sharesToAssetsFixedRatio(e);
//     mathint debtBefore = shareDebtToken0.balanceOf(user);
//     mathint balanceCollateralOtherSiloBefore = shareCollateralToken1.balanceOf(user);
//     mathint balanceProtectedCollateralOtherSilo = shareProtectedCollateralToken1.balanceOf(user);
//     requireCorrectSilo0Balance();
//     requireCorrectSilo1Balance();
//     require user == e.msg.sender;
//     require e.block.timestamp == currentContract.getSiloDataInterestRateTimestamp(); 
//     require debtBefore > 0;
//     require balanceCollateralOtherSiloBefore > 0;
//     require balanceCollateralOtherSiloBefore > debtBefore;

//     require balanceProtectedCollateralOtherSilo == 0; // assuming he's not on protected
//     require isSolvent(e, user);
    
//     uint256 _debtToCover;
//     bool _receiveSToken;
//     liquidationCall(e, token1, token0, user, _debtToCover, _receiveSToken);
//     satisfy true;
    
//     mathint debtAfter = shareDebtToken0.balanceOf(user);
//     mathint balanceCollateralOtherSiloAfter = shareCollateralToken1.balanceOf(user);
    
//     assert debtAfter > 0 => balanceCollateralOtherSiloAfter > debtAfter;
// }

// TODO investigate violation
// https://prover.certora.com/output/6893/57f9c9c15b144c3081ec908b82832b46/?anonymousKey=efe876a423f1f2556634aa752c0d3b7d81bb6510
// isSolvent -> getLtV is called with AccrueInterestInMemory = Yes, that increases the totabDebt and makes the user insolvent
// borrow -> getLtV is called with AccrueInterestInMemory = No, as it expects that accrueInterest was already called in the same block
// AccrueInterestInMemory = Yes doesn't call AccrueInterest. It calls getDebtAmountsWithInterest
// we have summaries for both AccrueInterest and getDebtAmountsWithInterest but it seems they're not linked
rule insolventCannotBorrow(env e, address user)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(e.msg.sender);
    sharesToAssetsFixedRatio(e);
    //sharesToAssetsNotTooHigh(e, 2);
    totalsNotTooHigh(e, 10^6);

    bool solvent = silo1.isSolvent(e, e.msg.sender);
    uint assets = 100;
    bool sameAsset;
    borrow@withrevert(e, assets, e.msg.sender, e.msg.sender, sameAsset);
    bool reverted = lastReverted;
    assert !solvent => reverted;
}

rule remainsSolventAfterInteraction(env e, method f) filtered { f -> !f.isView && !isIgnoredMethod(f) }
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(e.msg.sender);

    bool solventBefore = isSolvent(e, e.msg.sender);
    calldataarg args;
    f(e, args);
    bool solventAfter = isSolvent(e, e.msg.sender);
    assert solventBefore => solventAfter;
}

// TODO whitelist allowed storage changes
// the accrueInterest should not change most stuff but it DOES change minor things like interestRateTimestamp
rule accreuInterestDoesntAffectResult(env e, method f)
    filtered { f -> !f.isView }
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(e.msg.sender);

    storage init = lastStorage;
    calldataarg args;
    f(e, args);
    storage afterF = lastStorage;

    accrueInterest(e) at init;
    f(e, args);
    storage afterAccrue_F = lastStorage;
    assert afterF[currentContract] == afterAccrue_F[currentContract];
}