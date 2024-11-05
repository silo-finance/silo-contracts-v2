/* Integrity of main methods */

import "../summaries/two_silos_summaries.spec";
import "../summaries/siloconfig_dispatchers.spec";
import "../summaries/tokens_dispatchers.spec";
import "../summaries/safe-approximations.spec";

import "../requirements/tokens_requirements.spec";

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