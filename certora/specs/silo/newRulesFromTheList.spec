/* Integrity of main methods */

import "../requirements/CompleteSiloSetup.spec";
import "unresolved.spec";
import "../_simplifications/SiloMathLib.spec";
import "../_simplifications/Oracle_quote_one.spec";
import "../_simplifications/SimplifiedGetCompoundInterestRateAndUpdate.spec";

methods {
    
}

// accrueInterest doesn't affect sharesBalance
// state S -> call method f -> check balanceOf(user)
// state S -> call accrueInterest -> call method f -> check balanceOf(user)
rule accruingDoesntAffectShareBalance(env e, address user, method f)
    filtered { f -> !filterOutInInvariants(f) }
{
    SafeAssumptions_withInvariants_forMethod(e, user, f);
    storage init = lastStorage;
    calldataarg args;
    f(e, args);
    mathint shares1 = silo0.balanceOf(user);

    silo0.accrueInterest(e) at init;
    f(e, args);
    mathint shares2 = silo0.balanceOf(user);

    assert shares1 == shares2;
}

// accrueInterest() should never revert
rule accrueInterest_neverReverts(env e)
{
    require e.msg.value == 0;
    SafeAssumptionsEnv_withInvariants(e);

    _ = accrueInterest@withrevert(e);
    assert !lastReverted;
}

// if user has no debt, should always be solvent and ltv == 0
invariant noDebt_thenSolventAndNoLTV(env e, address user) 
    shareDebtToken0.balanceOf(user) == 0
     => (silo0.isSolvent(e, user) && getLTV(e, user) == 0)
    filtered { f -> !filterOutInInvariants(f) }
    {
    preserved with (env e2) { SafeAssumptions_withInvariants(e2, user); }
}


// accrueInterest() calling twice is the same as calling once (in a single block)
rule accrueInterest_idempotent(env e)
{
    SafeAssumptionsEnv_withInvariants(e);
    _ = accrueInterest(e);
    storage after1 = lastStorage;
    _ = accrueInterest(e);
    storage after2 = lastStorage;
    assert after1 == after2;
}

// withdrawFees() always reverts in a second call in the same block
//
rule withdrawFees_revertsSecondTime(env e)
{
    SafeAssumptionsEnv_withInvariants(e);
    withdrawFees(e);
    withdrawFees@withrevert(e);
    assert lastReverted;
}

// withdrawFees() always increases dao and/or deployer (can be empty address) balances
// another rule: withdrawFees() never increases daoAndDeployerRevenue in the same block
// ???
rule withdrawFees_increasesDaoDeploerFees(env e)
{
    SafeAssumptionsEnv_withInvariants(e);
    uint daoFeesBefore = getSiloDataDaoAndDeployerRevenue();
    withdrawFees(e);
    uint daoFeesAfter = getSiloDataDaoAndDeployerRevenue();
    assert daoFeesAfter > daoFeesBefore;
}

// withdrawFees() is ghost function - it should not influence result of 
// any other function in the system (including view functions results)
rule withdrawFees_noAdditionalEffect(env e, method f)
    filtered { f -> !filterOutInInvariants(f) }
{
    SafeAssumptionsEnv_withInvariants(e);
    storage init = lastStorage;
    calldataarg args;
    f(e, args);
    storage afterF = lastStorage;

    withdrawFees(e) at init;
    f(e, args);
    storage afterWF = lastStorage;

    assert afterF == afterWF;
}

// if borrowerCollateralSilo[user] is set from zero to non-zero value,
// it never goes back to zero
rule borrowerCollateralSilo_neverSetToZero(env e, method f) filtered { f -> !filterOutInInvariants(f) }
{
    address user;
    SafeAssumptions_withInvariants_forMethod(e, user, f);
    address colSiloBefore = config().borrowerCollateralSilo(e, user);
    
    calldataarg args;
    f(e, args);
    address colSiloAfter = config().borrowerCollateralSilo(e, user);
    assert colSiloBefore != 0 => colSiloAfter != 0;
}

// calling accrueInterestForSilo(_silo) should be equal to calling _silo.accrueInterest()
rule accrueInterestForSilo_equivalent(env e)
{

    // TODO compare storage manualyl instead, especially getSiloStorage()
    // totals of assets, etc. maybe even splt to several rules
    SafeAssumptionsEnv_withInvariants(e);
    storage init = lastStorage;
    siloConfig.accrueInterestForSilo(silo0);
    storage after1 = lastStorage;

    silo0.accrueInterest(e) at init;
    storage after2 = lastStorage;

    assert after1 == after2;
}

// if user is insolvent, it must have debt shares
invariant insolventHaveDebtShares(env e, address user) 
    !silo0.isSolvent(e, user) => shareDebtToken0.balanceOf(user) > 0
    filtered { f -> !filterOutInInvariants(f) }
    {
    preserved with (env e2) { SafeAssumptions_withInvariants(e2, user); }
}

invariant isSolvent_inEitherSilo(env e, address user)
    silo0.isSolvent(e, user) <=> silo1.isSolvent(e, user)
    filtered { f -> !filterOutInInvariants(f) }
    {
    preserved with (env e2) { SafeAssumptions_withInvariants(e2, user); }
}

// user should never have balance of debt share token in both silos
invariant cannotHaveDebtInBothSilos(env e, address user)
    !(shareDebtToken0.balanceOf(user) > 0 &&
        shareDebtToken1.balanceOf(user) > 0)
    filtered { f -> !filterOutInInvariants(f) }
    {
    preserved with (env e2) { SafeAssumptions_withInvariants(e2, user); }
}

// if borrowerCollateralSilo[user] is set from zero to non-zero value, 
// one of the debt share token totalSupply() increases 
rule borrowerCollateralSilo_setNonzeroIncreasesDebt (env e, method f)
     filtered { f -> !filterOutInInvariants(f) }
{
    address user;
    SafeAssumptions_withInvariants_forMethod(e, user, f);
    address colSiloBefore = config().borrowerCollateralSilo(e, user);
    uint totalShare0Before = shareDebtToken0.totalSupply();
    uint totalShare1Before = shareDebtToken1.totalSupply();

    calldataarg args;
    f(e, args);

    address colSiloAfter = config().borrowerCollateralSilo(e, user);
    uint totalShare0After = shareDebtToken0.totalSupply();
    uint totalShare1After = shareDebtToken1.totalSupply();

    assert (colSiloBefore == 0 && colSiloAfter != 0) 
        => (totalShare0After > totalShare0Before
            || totalShare1After > totalShare1Before);
}

// if borrowerCollateralSilo[user] is set from zero to non-zero value,
// user must have balance in one of debt share tokens
// excluding switchCollateralToThisSilo() method
rule borrowerCollateralSilo_setNonzeroIncreasesBalance (env e, method f)
    filtered { f -> !filterOutInInvariants(f) && 
                    f.selector != sig:switchCollateralToThisSilo().selector }
{
    address user;
    SafeAssumptions_withInvariants_forMethod(e, user, f);
    address colSiloBefore = config().borrowerCollateralSilo(e, user);

    calldataarg args;
    f(e, args);

    address colSiloAfter = config().borrowerCollateralSilo(e, user);
    uint debt0 = shareDebtToken0.balanceOf(user);
    uint debt1 = shareDebtToken1.balanceOf(user);

    assert (colSiloBefore == 0 && colSiloAfter != 0) 
        => (debt0 > 0 || debt1 > 0);
}

// withdraw() should never revert if liquidity for a user and a silo is sufficient even if oracle reverts
rule withdrawOnlyRevertsOnLiquidity(env e, address receiver)
{
    SafeAssumptions_withInvariants(e, receiver);

    uint256 assets;
    uint256 liquidity = getLiquidity(e);
    uint256 sharesPaid = withdraw@withrevert(e, assets, receiver, e.msg.sender);
    
    assert lastReverted => liquidity < assets;
    // todo also add check for user's balance of shares
    // user should have enought to withdraw

}

// user is always solvent after withdraw()
rule solventAfterWithdraw(env e, address receiver)
{
    SafeAssumptions_withInvariants(e, receiver);
        
    uint256 assets;
    uint256 sharesPaid = withdraw(e, assets, receiver, e.msg.sender);
    assert isSolvent(e, e.msg.sender);
}

// if user has debt, borrowerCollateralSilo[user] should be silo0 or silo1
// and one of shares tokens balances should not be 0
invariant debt_thenBorrowerCollateralSiloSetAndHasShares(env e, address user)
    (shareDebtToken0.balanceOf(user) > 0 || shareDebtToken1.balanceOf(user) > 0)
    => (
        (config().borrowerCollateralSilo(e, user) == silo0 && silo0.balanceOf(user) > 0) || 
        (config().borrowerCollateralSilo(e, user) == silo1 && silo1.balanceOf(user) > 0))
    filtered { f -> !filterOutInInvariants(f) }
    {
    preserved with (env e2) { SafeAssumptions_withInvariants(e2, user); }
}

// debt in two silos is impossible
invariant noDebtInBothSilos(env e, address user)
    shareDebtToken0.balanceOf(user) == 0  || shareDebtToken1.balanceOf(user) == 0
    filtered { f -> !filterOutInInvariants(f) }
    {
    preserved with (env e2) { SafeAssumptions_withInvariants(e2, user); }
}

// flashFee() returns non-zero value if fee is set to non-zero value
rule flashFee_nonZero(env e)
{
    SafeAssumptionsEnv_withInvariants(e);
    address token;
    uint amount; uint res;
    require amount > 0;
    uint256 daoFee; uint256 deployerFee; uint256 flashloanFee; address asset;
    daoFee, deployerFee, flashloanFee, asset = config().getFeesWithAsset(e, silo0);
    res = flashFee(e, token, amount);
    assert flashloanFee > 0 => res > 0;
}