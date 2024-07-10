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

//in development
rule RA_accreInterestIsCalledWhenItShould(env e, method f) filtered { f -> !f.isView && !isIgnoredMethod(f) }
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(e.msg.sender);
    calldataarg args;
    f(e, args);
    assert wasAccrueInterestCalled_silo0;
    assert wasAccrueInterestCalled_silo1;

    // if debt is in silo0
    //  assert is_silo0_acrrued
    // if !same_asset:
    //   assert is_silo1_acrrued
    // else
    //  assert is_silo1_acrrued
    // if !same_asset:
    //   assert is_silo0_acrrued
}

//In development
rule RA_withdrawingFeesDecreasesLiquidity(env e, method f) filtered { f -> !f.isView && !isIgnoredMethod(f) }
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(e.msg.sender);

    mathint feesBefore = getSiloDataDaoAndDeployerFees(e);
    mathint liquidityBefore = getLiquidity(e);

    calldataarg args;
    f(e, args);

    mathint feesAfter = getSiloDataDaoAndDeployerFees(e);
    mathint liquidityAfter = getLiquidity(e);
    
    mathint feesDiff = feesAfter - feesBefore;
    mathint liquidityDiff = liquidityBefore - liquidityAfter;

    assert (feesDiff > 0 && liquidityAfter > 0) => liquidityDiff >= feesDiff;
}

// In development
// A user should not be able to fully repay a loan with less amount than he borrowed.
rule RA_Silo_no_negative_interest_for_loan(env e, address user)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(user);
    totalSupplyMoreThanBalance(e.msg.sender);
    
    bool sameAsset;
    uint256 assetsBorrowed;
    mathint debt = borrow(e, assetsBorrowed, user, e.msg.sender, sameAsset);
    uint256 assetsRepayed;
    mathint debtPaid = repay(e, assetsRepayed, e.msg.sender);
    
    assert assetsBorrowed > assetsRepayed => debt > debtPaid;
}

// In development
// A user should not be able to fully repay a loan with less amount than he borrowed.
// Even if there's a method called in between.
rule RA_Silo_no_negative_interest_for_loan_Param(env e, address user, method f)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(user);
    totalSupplyMoreThanBalance(e.msg.sender);
    
    bool sameAsset;
    uint256 assetsBorrowed;
    mathint debt = borrow(e, assetsBorrowed, user, e.msg.sender, sameAsset);
    calldataarg args;
    f(e, args);
    uint256 assetsRepayed;
    mathint debtPaid = repay(e, assetsRepayed, e.msg.sender);
    
    assert assetsBorrowed > assetsRepayed => debt > debtPaid;
}

// Rest of the rules are written correctly but they timeout.
// We need to adjust prover setting, run parametric rules in separate jobs, weeken the rules or use better summaries


// A user cannot redeem anything after redeeming whole balance.
rule RA_Silo_no_redeem_after_redeeming_all(env e, address user, ISilo.CollateralType type)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(user);
    totalSupplyMoreThanBalance(e.msg.sender);

    uint256 balanceBefore;
    if(type == ISilo.CollateralType.Collateral) {
        require balanceBefore == shareCollateralToken0.balanceOf(user);
    }
    else if(type == ISilo.CollateralType.Protected) {
        require balanceBefore == shareProtectedCollateralToken0.balanceOf(user);
    }
    else {
        require false;
    }
    
    mathint assets = redeem(e, balanceBefore, user, user, type);
    uint256 shares;
    redeem@withrevert(e, shares, user, user, type);
    assert lastReverted;


}

/// @title User should not be able to borrow more than maxBorrow().
/// Violated (but not a real issue - maxBorrow() could under-estimate)
rule RA_silo_cant_borrow_more_than_max(env e, address borrower) {
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(borrower);
    bool sameAsset;
    
    uint256 maxAssets = maxBorrow(e, borrower, sameAsset);
    uint256 assets; address receiver; 
    borrow(e, assets, receiver, borrower, sameAsset);

    assert assets <= maxAssets;
}

/// @title User should not be able to borrow without collateral.
rule RA_silo_cant_borrow_without_collateral(env e, address borrower) {
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(borrower);
    bool sameAsset;

    require silo0.total(require_uint256(ISilo.AssetType.Protected)) + silo0.total(require_uint256(ISilo.AssetType.Collateral)) <= max_uint256;
    require silo1.total(require_uint256(ISilo.AssetType.Protected)) + silo1.total(require_uint256(ISilo.AssetType.Collateral)) <= max_uint256;
    require shareProtectedCollateralToken0.totalSupply() + shareCollateralToken0.totalSupply() <= max_uint256;
    require shareProtectedCollateralToken1.totalSupply() + shareCollateralToken1.totalSupply() <= max_uint256;
    SafeAssumptions(e);

    uint256 collateralShares = shareCollateralToken1.balanceOf(borrower);
    uint256 protectedCollateralShares = shareProtectedCollateralToken1.balanceOf(borrower);
    uint256 maxAssets = maxBorrow(e, borrower, sameAsset);
    assert collateralShares == 0 && protectedCollateralShares ==0 => maxAssets == 0;
}

/// @title If there is no collateral in the system, there couldn't be any debt.
invariant RA_no_collateral_assets_no_debt_assets()
    silo0.total(require_uint256(ISilo.AssetType.Collateral)) ==0 &&
    silo0.total(require_uint256(ISilo.AssetType.Protected)) ==0 =>
    (   
        /// Liquidity constraint
        silo0.total(require_uint256(ISilo.AssetType.Debt)) ==0 
        &&
        /// Solvency constraint
        silo1.total(require_uint256(ISilo.AssetType.Debt)) ==0
    )
    {
        preserved with (env e) {
            SafeAssumptions(e);
            require isSolvent(e, e.msg.sender);
        }
    }

/*
Violation analysis:

- accrueInterest:
    While the total supply of the collateral share token is zero,
    interest accretion from the debt token is possible through
    SiloMathLib.getCollateralAmountsWithInterest which will increase
    total[AssetType.collateral].assets by the interest.

    hence the violation shows:
    ShareCollateralToken.totalSupply() == 0 but total[AssetType.collateral].assets ! =0

    TOTAL SUPPLY = 0 ; TOTAL ASSETS = Y
    TOTAL_SUPPLY = +X ; TOTAL_ASSETS = Y + X

    Conclusion:
    For the case of bad debt (debt shares are available without collateral shares),

*/
invariant RA_zero_assets_iff_zero_shares() 
    (silo0.total(require_uint256(ISilo.AssetType.Protected)) ==0 <=> shareProtectedCollateralToken0.totalSupply() == 0) &&
    (silo0.total(require_uint256(ISilo.AssetType.Collateral)) ==0 <=> shareCollateralToken0.totalSupply() == 0) &&
    (silo0.total(require_uint256(ISilo.AssetType.Debt)) ==0 <=> shareDebtToken0.totalSupply() == 0) 
    {
        preserved with (env e) {
            completeSiloSetupEnv(e);
            totalSupplyMoreThanBalance(e.msg.sender);
            requireInvariant RA_no_collateral_assets_no_debt_assets();
        }
    }

invariant RA_more_assets_than_shares() 
    (silo0.total(require_uint256(ISilo.AssetType.Protected)) >= shareProtectedCollateralToken0.totalSupply()) &&
    (silo0.total(require_uint256(ISilo.AssetType.Collateral)) >= shareCollateralToken0.totalSupply()) &&
    (silo0.total(require_uint256(ISilo.AssetType.Debt)) >= shareDebtToken0.totalSupply()) 
    {
        preserved with (env e) {
            SafeAssumptions(e);
        }
    }

/// @title Repaying cannot turn a user to insolvent.
rule RA_silo_solvent_after_repaying(env e, address borrower) {
    SafeAssumptions(e);

    require isSolvent(e, borrower);
        uint256 assets;
        repay(e, assets, borrower);
    assert isSolvent(e, borrower);
}

/// @title A borrower must be solvent after borrowing.
rule RA_silo_solvent_after_borrow(env e, address borrower) {
    SafeAssumptions(e);
    
    bool sameAsset;
    uint256 assets;
    address receiver;
    borrow(e, assets, receiver, borrower, sameAsset);
    assert isSolvent(e, borrower);
}

/// @title deposit() preserves the user's solvency.
rule RA_silo_solvent_after_deposit(env e, address borrower) {
    SafeAssumptions(e);
    
    uint256 assets;
    address receiver;
    require silo0.getSiloDataInterestRateTimestamp() == e.block.timestamp;
    require isSolvent(e, borrower);
        deposit(e, assets, receiver);
    assert isSolvent(e, borrower);
}

/// @title An actor without allowance cannot decrease (increase) the collateral (debt) share balance of any user.
rule RA_user_cannot_lower_shares_balance_of_another(env e, address user, method f) 
    filtered { f -> !f.isView && !isIgnoredMethod(f) } {
    totalSupplyMoreThanBalance(user);
    SafeAssumptions(e);
    require e.msg.sender != user;

    /// No accrual of interest
    require silo0.getSiloDataInterestRateTimestamp() == e.block.timestamp;
    /// No allowance
    require shareDebtToken1.allowance(e, user, e.msg.sender) == 0;
    require shareCollateralToken0.allowance(e, user, e.msg.sender) == 0;
    require shareProtectedCollateralToken0.allowance(e, user, e.msg.sender) == 0;

    mathint balanceDebt_before = shareDebtToken1.balanceOf(user);
    mathint balanceCol_before = shareCollateralToken0.balanceOf(user);
    mathint balancePro_before = shareProtectedCollateralToken0.balanceOf(user);
        calldataarg args;
        f(e, args);
    mathint balanceDebt_after = shareDebtToken1.balanceOf(user);
    mathint balanceCol_after = shareCollateralToken0.balanceOf(user);
    mathint balancePro_after = shareProtectedCollateralToken0.balanceOf(user);

    if (f.selector == withdrawCollateralToLiquidatorSig()) {
        /// The function is called from within liquidationCall() of the other Silo.
        assert e.msg.sender == silo1;
    }
    else {
        assert balanceDebt_before >= balanceDebt_after, "Debt balance cannot increase by other user";
        assert balanceCol_before <= balanceCol_after, "Collateral balance cannot decrease by other user";
        assert balancePro_before <= balancePro_after, "Protected balance cannot decrease by other user";
    }
}

/// @title If the collateral and debt shares balance of a user aren't changed,
/// then the assets data aren't changed too.
rule RA_assets_values_depend_on_shares_balances_only(env e, address user, method f) 
        filtered { f -> !f.isView && !isIgnoredMethod(f) } {
    SafeAssumptions(e);
    /// No accrual of interest - we have proven that the assets value are conserved under interest accrual.
    require silo0.getSiloDataInterestRateTimestamp() == e.block.timestamp;

    SiloSolvencyLib.LtvData data_before = getAssetsDataForLtvCalculations(e, user);
    mathint balanceDebt_before = shareDebtToken1.balanceOf(user);
    mathint balanceCol_before = shareCollateralToken0.balanceOf(user);
    mathint balancePro_before = shareProtectedCollateralToken0.balanceOf(user);
        calldataarg args;
        f(e, args);
    SiloSolvencyLib.LtvData data_after = getAssetsDataForLtvCalculations(e, user);
    mathint balanceDebt_after = shareDebtToken1.balanceOf(user);
    mathint balanceCol_after = shareCollateralToken0.balanceOf(user);
    mathint balancePro_after = shareProtectedCollateralToken0.balanceOf(user);

    assert (
        balanceDebt_before == balanceDebt_after && 
        balanceCol_before == balanceCol_after &&
        balancePro_after == balancePro_before
    ) => 
    (
        data_before.borrowerProtectedAssets == data_after.borrowerProtectedAssets &&
        data_before.borrowerCollateralAssets == data_after.borrowerCollateralAssets &&
        data_before.borrowerDebtAssets == data_after.borrowerDebtAssets
    );
}

/// @title An immediate withdraw after deposit by the same actor of the same amount must succeed.
rule RA_can_withdraw_after_deposit(env e) {
    SafeAssumptions(e);

    uint256 amount;
    require silo0.total(require_uint256(ISilo.AssetType.Protected)) + silo0.total(require_uint256(ISilo.AssetType.Collateral)) + amount <= max_uint128;
    require silo1.total(require_uint256(ISilo.AssetType.Protected)) + silo1.total(require_uint256(ISilo.AssetType.Collateral)) + amount <= max_uint128;
    
    /// If the user isn't solvent in the first place, withdrawal cannot succeed. 
    require isSolvent(e, e.msg.sender);
    /// If there is bad debt in the system, the deposit will cover the bad debt and the withdrawal will be limited.
    require getLiquidity(e) > 0;

    deposit(e, amount, e.msg.sender);
    uint256 oneShareValue = silo0.convertToAssets(e, 1, ISilo.AssetType.Collateral);
    uint256 amountToWithdraw = amount > oneShareValue ? assert_uint256(amount - oneShareValue) : 0;
    withdraw@withrevert(e, amountToWithdraw, e.msg.sender, e.msg.sender);

    assert amountToWithdraw > 0 => !lastReverted;
}

/// @title An immediate redeem after deposit by the same actor of the minted shares must succeed.
rule RA_can_redeem_after_deposit(env e) {
    SafeAssumptions(e);

    uint256 amount;
    require silo0.total(require_uint256(ISilo.AssetType.Protected)) + silo0.total(require_uint256(ISilo.AssetType.Collateral)) + amount <= max_uint128;
    require silo1.total(require_uint256(ISilo.AssetType.Protected)) + silo1.total(require_uint256(ISilo.AssetType.Collateral)) + amount <= max_uint128;
    /// If the user isn't solvent in the first place, withdrawal cannot succeed. 
    require isSolvent(e, e.msg.sender);
    /// If there is bad debt in the system, the deposit will cover the bad debt and the withdrawal will be limited.
    require getLiquidity(e) > 0;

    uint256 shares = deposit(e, amount, e.msg.sender);
    uint256 shareBalance = shareCollateralToken0.balanceOf(e.msg.sender);
    uint256 sharesToWithdraw = shares > shareBalance ? shareBalance : shares;
    redeem@withrevert(e, sharesToWithdraw, e.msg.sender, e.msg.sender);

    assert !lastReverted;
}