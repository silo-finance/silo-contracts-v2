import "../_common/CompleteSiloSetup.spec";
import "../_common/IsSiloFunction.spec";
import "../_common/SiloMethods.spec";
import "../_common/Helpers.spec";
import "../_common/CommonSummarizations.spec";
//import "../../_simplifications/Oracle_quote_one.spec";
import "../../_simplifications/priceOracle.spec";
//import "../../_simplifications/Silo_isSolvent_ghost.spec";
import "../../_simplifications/SiloSolvencyLib.spec";
import "../../_simplifications/SimplifiedGetCompoundInterestRateAndUpdate.spec";

/*
rule remainsSolventAfterSelfLiquidation(env e, address user)
{
    completeSiloSetupEnv(e);
    completeSiloSetupAddress(user);
    totalSupplyMoreThanBalance(user);
    mathint debtBefore = shareDebtToken0.balanceOf(user);
    mathint balanceCollateralOtherSiloBefore = shareCollateralToken1.balanceOf(user);
    mathint balanceProtectedCollateralOtherSilo = shareProtectedCollateralToken1.balanceOf(user);
    requireCorrectSilo0Balance();
    requireCorrectSilo1Balance();
    
    require balanceProtectedCollateralOtherSilo == 0; // assuming he's not on protected
    require isSolvent(e, user);
    
    uint256 _debtToCover;
    bool _receiveSToken;
    liquidationCall(e, token1, token0, user, _debtToCover, _receiveSToken);
    satisfy true;
    
    mathint debtAfter = shareDebtToken0.balanceOf(user);
    mathint balanceCollateralOtherSiloAfter = shareCollateralToken1.balanceOf(user);

    assert debtAfter > 0 => balanceCollateralOtherSiloAfter > 0;
 
}
*/

rule insolventCannotBorrow(env e, address user)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(e.msg.sender);

    bool solvent = isSolvent(e, e.msg.sender);
    uint assets;
    borrow@withrevert(e, assets, e.msg.sender, e.msg.sender);
    bool reverted = lastReverted;
    assert !solvent => reverted;
}

rule remainsSolventAfterInteraction(env e, method f)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(e.msg.sender);

    bool solventBefore = isSolvent(e, e.msg.sender);
    calldataarg args;
    f(e, args);
    bool solventAfter = isSolvent(e, e.msg.sender);
    assert solventBefore => solventAfter;
}

rule accreuInterestDoesntAffectResult(env e, method f)
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