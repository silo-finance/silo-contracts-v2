/* Integrity of main methods */

import "../summaries/two_silos_summaries.spec";
import "../summaries/siloconfig_dispatchers.spec";
import "../summaries/tokens_dispatchers.spec";
import "../summaries/safe-approximations.spec";

import "../requirements/tokens_requirements.spec";
import "../previousAudits/CompleteSiloSetup.spec";

using Silo0 as silo0;
using Silo1 as silo1;
using Token0 as token0;
using Token1 as token1;
using ShareDebtToken0 as shareDebtToken0;
using ShareDebtToken1 as shareDebtToken1;


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
}

// borrow() user borrows maxAssets returned by maxBorrow, 
// borrow should not revert because of solvency check
rule maxBorrow_correctness(env e)
{
    address user; address receiver;
    uint256 maxB = maxBorrow(e, user);

    silosTimestampSetupRequirements(e);
    nonSceneAddressRequirements(receiver);
    totalSuppliesMoreThanBalances(receiver, silo0);

    _ = borrow@withrevert(e, maxB, receiver, user);
    assert !lastReverted;
}

// accrueInterest() should never revert
rule accrueInterest_neverReverts(env e)
{
    silosTimestampSetupRequirements(e);

    _ = accrueInterest@withrevert(e);
    assert !lastReverted;
}

// if user has no debt, should always be solvent and ltv == 0
invariant noDebt_thenSolventAndNoLTV(env e, address user)
    shareDebtToken0.balanceOf(user) == 0
     => (silo0.isSolvent(e, user) &&
         getLTV(e, user) == 0);

// accrueInterest() calling twice is the same as calling once (in a single block)
rule accrueInterest_idempotent(env e)
{
    silosTimestampSetupRequirements(e);
    _ = accrueInterest(e);
    storage after1 = lastStorage;
    _ = accrueInterest(e);
    storage after2 = lastStorage;
    assert after1 == after2;
}

// withdrawFees() always reverts in a second call in the same block
rule withdrawFees_revertsSecondTime(env e)
{
    silosTimestampSetupRequirements(e);
    withdrawFees(e);
    withdrawFees@withrevert(e);
    assert lastReverted;
}

// withdrawFees() always increases dao and/or deployer (can be empty address) balances
// another rule: withdrawFees() never increases daoAndDeployerRevenue in the same block
// ???
rule withdrawFees_increasesDaoDeploerFees(env e)
{
    silosTimestampSetupRequirements(e);
    uint daoFeesBefore = getSiloDataDaoAndDeployerRevenue(e);
    withdrawFees(e);
    uint daoFeesAfter = getSiloDataDaoAndDeployerRevenue(e);
    assert daoFeesAfter > daoFeesBefore;
}

// withdrawFees() is ghost function - it should not influence result of 
// any other function in the system (including view functions results)
rule withdrawFees_noAdditionalEffect(env e, method f)
{
    silosTimestampSetupRequirements(e);
    storage init = lastStorage;
    calldataarg args;
    f(e, args);
    storage afterF = lastStorage;

    withdrawFees(e) at init;
    f(e, args);
    storage afterWF = lastStorage;

    assert afterF == afterWF;
}

// maxRepay() should never return more than totalAssets[AssetType.Debt]
rule maxRepay_neverGreaterThanTotalDebt(env e)
{
    silosTimestampSetupRequirements(e);
    address user;
    uint res = maxRepay(e, user);
    uint max = silo0.getTotalAssetsStorage(ISilo.AssetType.Debt);
    assert res <= max;
}

// if borrowerCollateralSilo[user] is set from zero to non-zero value,
// it never goes back to zero
rule borrowerCollateralSilo_neverSetToZero(env e, method f) // TODO exclude view
{
    silosTimestampSetupRequirements(e);
    address user;
    address colSiloBefore = config(e).borrowerCollateralSilo(e, user);
    
    calldataarg args;
    f(e, args);
    address colSiloAfter = config(e).borrowerCollateralSilo(e, user);
    assert colSiloBefore != 0 => colSiloAfter != 0;
}

// calling accrueInterestForSilo(_silo) should be equal to calling _silo.accrueInterest()
rule accrueInterestForSilo_equivalent(env e)
{
    silosTimestampSetupRequirements(e);
    storage init = lastStorage;
    _ = config(e).accrueInterestForSilo(e, silo0);
    storage after1 = lastStorage;

    silo0.accrueInterest(e) at init;
    storage after2 = lastStorage;

    assert after1 == after2;
}



// if user is insolvent, it must have debt shares
invariant insolventHaveDebtShares(env e, address user)
    !silo0.isSolvent(e, user) => shareDebtToken0.balanceOf(user) > 0;

//////////////////////////
//// Rules bellow require setup for both silos
/////////////////////////

invariant isSolvent_inEitherSilo(env e, address user)
    silo0.isSolvent(e, user) <=> silo1.isSolvent(e, user);

// user should never have balance of debt share token in both silos
invariant cannotHaveDebtInBothSilos(env e, address user)
    !(shareDebtToken0.balanceOf(user) > 0 &&
        shareDebtToken1.balanceOf(user) > 0);


// if borrowerCollateralSilo[user] is set from zero to non-zero value, 
// one of the debt share token totalSupply() increases 
rule borrowerCollateralSilo_setNonzeroIncreasesDebt (env e, method f) // TODO exclude view
{
    silosTimestampSetupRequirements(e);
    address user;
    address colSiloBefore = config(e).borrowerCollateralSilo(e, user);
    uint totalShare0Before = shareDebtToken0.totalSupply();
    uint totalShare1Before = shareDebtToken1.totalSupply();

    calldataarg args;
    f(e, args);

    address colSiloAfter = config(e).borrowerCollateralSilo(e, user);
    uint totalShare0After = shareDebtToken0.totalSupply();
    uint totalShare1After = shareDebtToken1.totalSupply();

    assert (colSiloBefore == 0 && colSiloAfter != 0) 
        => (totalShare0After > totalShare0Before
            || totalShare1After > totalShare1Before);
}

// if borrowerCollateralSilo[user] is set from zero to non-zero value,
// user must have balance in one of debt share tokens
// excluding switchCollateralToThisSilo() method
rule borrowerCollateralSilo_setNonzeroIncreasesBalance (env e, method f) // TODO exclude view and switchCollateralToThisSilo
{
    silosTimestampSetupRequirements(e);
    address user;
    address colSiloBefore = config(e).borrowerCollateralSilo(e, user);

    calldataarg args;
    f(e, args);

    address colSiloAfter = config(e).borrowerCollateralSilo(e, user);
    uint debt0 = shareDebtToken0.balanceOf(e, user);
    uint debt1 = shareDebtToken1.balanceOf(e, user);

    assert (colSiloBefore == 0 && colSiloAfter != 0) 
        => (debt0 > 0 || debt1 > 0);
}