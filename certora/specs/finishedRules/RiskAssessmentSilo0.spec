import "../_common/CompleteSiloSetup.spec";
import "../_common/IsSiloFunction.spec";
import "../_common/SiloMethods.spec";
import "../_common/Helpers.spec";
import "../_common/CommonSummarizations.spec";
import "../_simplifications/priceOracle.spec";
import "../_simplifications/SiloMathLib.spec";
import "../_simplifications/SimplifiedGetCompoundInterestRateAndUpdate.spec";
import "../_common/AccrueInterestWasCalled_hook.spec";

use rule assetsToSharesAndBackAxiom;
use rule mulDiv_axioms_test;

function SafeAssumptions(env e) {
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(e.msg.sender);
    requireProtectedToken0TotalAndBalancesIntegrity();
    requireCollateralToken0TotalAndBalancesIntegrity();
    requireDebtToken0TotalAndBalancesIntegrity();
    requireProtectedToken1TotalAndBalancesIntegrity();
    requireCollateralToken1TotalAndBalancesIntegrity();
    requireDebtToken1TotalAndBalancesIntegrity();
    requireInvariant RA_more_assets_than_shares();
    require silo0.getSiloDataInterestRateTimestamp() > 0;
    require silo0.getSiloDataInterestRateTimestamp() <= e.block.timestamp;
    require silo1.getSiloDataInterestRateTimestamp() > 0;
    require silo1.getSiloDataInterestRateTimestamp() <= e.block.timestamp;
    require silo0.total(require_uint256(ISilo.AssetType.Protected)) + silo0.total(require_uint256(ISilo.AssetType.Collateral)) <= max_uint256;
    require silo1.total(require_uint256(ISilo.AssetType.Protected)) + silo1.total(require_uint256(ISilo.AssetType.Collateral)) <= max_uint256;
}

// violated - reported bug
invariant RA_reentrancyGuardStaysUnlocked(env e)
    isPublicCall(e) => silo0.reentrancyGuardEntered() == false
    { preserved with (env e1) 
        { 
            completeSiloSetupEnv(e1);
            require e1 == e; 
        } 
}


//violated - reported bug
rule RA_reentrancyGuardStatus_change(env e, method f) filtered 
    { f -> !f.isView && !isIgnoredMethod(f) }
{
    completeSiloSetupEnv(e);
    uint256 statusBefore = reentrancyGuardStatus(e);
    require isPublicCall(e);
    calldataarg args;
    f(e, args);
    uint256 statusAfter = reentrancyGuardStatus(e);
    assert statusBefore == 1 => statusAfter == 1;   // not entered
    assert statusBefore >= 1 => statusAfter >= 1;   // entered from internal contracts
}

// this rule just marks all the methods that calls crossNonReentrantBefore
// the methods that call it will be red (violated) in the dashboard.
rule RA_whoCanCallCrossNonReentrantBefore(env e, method f) filtered { f -> !f.isView }
{
    completeSiloSetupEnv(e);
    require wasCalled_crossNonReentrantBefore(e) == false;
    calldataarg args;
    f(e, args);
    bool wasCalledAfter = wasCalled_crossNonReentrantBefore(e);
    assert !wasCalledAfter;
}

// this rule just marks all the methods that calls crossNonReentrantAfter
// the methods that call it will be red (violated) in the dashboard.
rule RA_whoCanCallCrossNonReentrantAfter(env e, method f) filtered { f -> !f.isView }
{
    completeSiloSetupEnv(e);
    require wasCalled_crossNonReentrantAfter(e) == false;
    calldataarg args;
    f(e, args);
    bool wasCalledAfter = wasCalled_crossNonReentrantAfter(e);
    assert mustCallCrossNonReentrant(f) => wasCalledAfter;
}

//violated - reported bug
rule RA_whoMustCallCrossNonReentrantBefore(env e, method f) filtered { f -> !f.isView && !isIgnoredMethod(f) }
{
    completeSiloSetupEnv(e);
    require wasCalled_crossNonReentrantBefore(e) == false;
    calldataarg args;
    f(e, args);
    bool wasCalledAfter = wasCalled_crossNonReentrantBefore(e);
    assert mustCallCrossNonReentrant(f) => wasCalledAfter;
}

//violated - reported bug
rule RA_whoMustCallCrossNonReentrantAfter(env e, method f) filtered { f -> !f.isView && !isIgnoredMethod(f) }
{
    completeSiloSetupEnv(e);
    require wasCalled_crossNonReentrantAfter(e) == false;
    calldataarg args;
    f(e, args);
    bool wasCalledAfter = wasCalled_crossNonReentrantAfter(e);
    assert mustCallCrossNonReentrant(f) => wasCalledAfter;
}

/// @title A user has no debt after being repaid with max shares amount.
rule RA_Silo_repay_all_shares(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);
    
    mathint debtBefore = shareDebtToken0.balanceOf(receiver);
    uint256 maxRepayShares = maxRepayShares(e, receiver);
    
    mathint assetsR = repayShares(e, maxRepayShares, receiver);
    mathint debtAfter = shareDebtToken0.balanceOf(receiver);  

    assert debtAfter == 0;
    satisfy debtAfter == 0;
}

/// @title If a user may deposit some amount, any other user also may.
rule RA_anyone_may_deposit(env e1, env e2) {
    /// Assuming same context (time and value).
    require e1.block.timestamp == e2.block.timestamp;
    require e1.msg.value == e2.msg.value;
    SafeAssumptions(e1);
    SafeAssumptions(e2);

    storage initState = lastStorage;
    uint256 amount;
    address recipient;

    require silo0 !=0;
    /// Given the other user has approved the Silo allowance.
    require token0.allowance(e2, e2.msg.sender, silo0) >= amount;
    /// Assuming sufficient balance for deposit.
    require token0.balanceOf(e2, e2.msg.sender) >= amount;

    deposit(e1, amount, recipient) at initState;
    deposit@withrevert(e2, amount, recipient) at initState;

    assert e2.msg.sender !=0 => !lastReverted;
}

/// @title If a user may repay some borrower's debt amount, any other user also may.
rule RA_anyone_may_repay(env e1, env e2) {
    /// Assuming same context (time and value).
    require e1.block.timestamp == e2.block.timestamp;
    require e1.msg.value == e2.msg.value;
    SafeAssumptions(e1);
    SafeAssumptions(e2);

    storage initState = lastStorage;
    uint256 amount;
    address borrower;

    require silo0 !=0;
    /// Given the other user has approved the Silo allowance.
    require token0.allowance(e2, e2.msg.sender, silo0) >= amount;
    /// Assuming sufficient balance:
    require token0.balanceOf(e2, e2.msg.sender) >= amount;

    repay(e1, amount, borrower) at initState;
    repay@withrevert(e2, amount, borrower) at initState;

    assert e2.msg.sender !=0 => !lastReverted;
}

/// @title The deposit recipient is not discriminated.
rule RA_deposit_recipient_is_not_restricted(env e, address user1, address user2) {
    SafeAssumptions(e);

    storage initState = lastStorage;
    uint256 amount;

    require silo0 !=0;
    /// deposit possible for user2 (might be deprecated in the future).
    require shareDebtToken0.balanceOf(user2) == 0;

    deposit(e, amount, user1) at initState;
    deposit@withrevert(e, amount, user2) at initState;

    assert user2 !=0 => !lastReverted;
}

/// @title The repay action of a borrower is not discriminated.
rule RA_repay_borrower_is_not_restricted(env e, address borrower1, address borrower2) {
    SafeAssumptions(e);

    storage initState = lastStorage;
    uint256 amount;

    require silo0 !=0;
    /// Get the borrower's debt in assets.
    uint256 borrower2_debt = silo0.convertToAssets(
        e, shareDebtToken0.balanceOf(borrower2), ISilo.AssetType.Debt
    );

    repay(e, amount, borrower1) at initState;
    repay@withrevert(e, amount, borrower2) at initState;

    /// If the repaid amount is less than the borrower's debt then the operation must succeed.
    assert (amount <= borrower2_debt && borrower2 !=0) => !lastReverted;
}
