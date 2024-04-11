import "../_common/CompleteSiloSetup.spec";
import "../_common/IsSiloFunction.spec";
import "../_common/SiloMethods.spec";
import "../_common/Helpers.spec";
import "../_common/CommonSummarizations.spec";
import "../../_simplifications/priceOracle.spec";
import "../../_simplifications/SiloMathLib.spec";
import "../../_simplifications/SimplifiedGetCompoundInterestRateAndUpdate.spec";

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
    require silo0.total(ISilo.AssetType.Protected) + silo0.total(ISilo.AssetType.Collateral) <= max_uint256;
    require silo1.total(ISilo.AssetType.Protected) + silo1.total(ISilo.AssetType.Collateral) <= max_uint256;
}

// A user cannot withdraw anything after withdrawing whole balance.
// holds
// https://prover.certora.com/output/6893/6ebdfe9df3f04b4b887bdb1c5372637c/?anonymousKey=af1886c64a28e05f1ee50a3c98745a75596a38ad
rule RA_Silo_no_withdraw_after_withdrawing_all(env e, address user, ISilo.AssetType type)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(user);
    totalSupplyMoreThanBalance(e.msg.sender);

    uint256 balanceBefore;
    if(type == ISilo.AssetType.Collateral) {
        require balanceBefore == shareCollateralToken0.balanceOf(user);
    }
    else if(type == ISilo.AssetType.Protected) {
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

// A user should not be able to fully repay a loan with less amount than he borrowed, if there's a method called in between.
rule RA_Silo_no_negative_interest_for_loan(env e, address user, method f)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(user);
    totalSupplyMoreThanBalance(e.msg.sender);
    
    uint256 assetsBorrowed;
    mathint debt = borrow(e, assetsBorrowed, user, e.msg.sender);
    calldataarg args;
    f(e, args);
    uint256 assetsRepayed;
    mathint debtPaid = repay(e, assetsRepayed, e.msg.sender);
    
    assert assetsBorrowed > assetsRepayed => debt > debtPaid;
}

/*
// A user should not be able to deposit an asset that he borrowed in the Silo.
// violated
// DEPRECATED - No longer applicable in current version
rule RA_Silo_borrowed_asset_not_depositable(env e, address user)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(user);
    totalSupplyMoreThanBalance(e.msg.sender);
    
    mathint debtBefore = shareDebtToken0.balanceOf(e.msg.sender);
    require debtBefore > 0;
    uint256 assets;
    mathint sharesD = deposit@withrevert(e, assets, user);
    assert lastReverted;
}
*/

/// @title A user has no debt after being repaid with max shares amount.
// holds
// https://prover.certora.com/output/6893/a22af9f11ffb407bb7e4cf394cb3055e/?anonymousKey=9509c87048a98ee81867020227f1441090132ff9
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

/// @title User should not be able to borrow more than maxBorrow().
/// Violated: rounding errors.
rule RA_silo_cant_borrow_more_than_max(env e, address borrower) {
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(borrower);

    
    uint256 maxAssets = maxBorrow(e, borrower);
    uint256 assets; address receiver; 
    borrow(e, assets, receiver, borrower);

    assert assets <= maxAssets;
}

/// @title User should not be able to borrow without collateral.
rule RA_silo_cant_borrow_without_collateral(env e, address borrower) {
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(borrower);

    require silo0.total(ISilo.AssetType.Protected) + silo0.total(ISilo.AssetType.Collateral) <= max_uint256;
    require silo1.total(ISilo.AssetType.Protected) + silo1.total(ISilo.AssetType.Collateral) <= max_uint256;
    require shareProtectedCollateralToken0.totalSupply() + shareCollateralToken0.totalSupply() <= max_uint256;
    require shareProtectedCollateralToken1.totalSupply() + shareCollateralToken1.totalSupply() <= max_uint256;
    SafeAssumptions(e);

    uint256 collateralShares = shareCollateralToken1.balanceOf(borrower);
    uint256 protectedCollateralShares = shareProtectedCollateralToken1.balanceOf(borrower);
    uint256 maxAssets = maxBorrow(e, borrower);
    assert collateralShares == 0 && protectedCollateralShares ==0 => maxAssets == 0;
}

/// @title If there is no collateral in the system, there couldn't be any debt.
/// Violated: case of bad debt.
invariant RA_no_collateral_assets_no_debt_assets()
    silo0.total(ISilo.AssetType.Collateral) ==0 &&
    silo0.total(ISilo.AssetType.Protected) ==0 =>
    (   
        /// Liquidity constraint
        silo0.total(ISilo.AssetType.Debt) ==0 
        &&
        /// Solvency constraint
        silo1.total(ISilo.AssetType.Debt) ==0
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
    (silo0.total(ISilo.AssetType.Protected) ==0 <=> shareProtectedCollateralToken0.totalSupply() == 0) &&
    (silo0.total(ISilo.AssetType.Collateral) ==0 <=> shareCollateralToken0.totalSupply() == 0) &&
    (silo0.total(ISilo.AssetType.Debt) ==0 <=> shareDebtToken0.totalSupply() == 0) 
    {
        preserved with (env e) {
            completeSiloSetupEnv(e);
            totalSupplyMoreThanBalance(e.msg.sender);
            requireInvariant RA_no_collateral_assets_no_debt_assets();
        }
    }

invariant RA_more_assets_than_shares() 
    (silo0.total(ISilo.AssetType.Protected) >= shareProtectedCollateralToken0.totalSupply()) &&
    (silo0.total(ISilo.AssetType.Collateral) >= shareCollateralToken0.totalSupply()) &&
    (silo0.total(ISilo.AssetType.Debt) >= shareDebtToken0.totalSupply()) 
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
    
    uint256 assets;
    address receiver;
    borrow(e, assets, receiver, borrower);
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
filtered{f -> !f.isView} {
    totalSupplyMoreThanBalance(user);
    SafeAssumptions(e);
    require e.msg.sender != user;

    /// No accrual of interest
    require silo0.getSiloDataInterestRateTimestamp() == e.block.timestamp;
    /// No allowance
    require shareDebtToken1.allowance(e, user, e.msg.sender) == 0;
    require shareCollateralToken0.allowance(e, user, e.msg.sender) == 0;
    require shareProtectedCollateralToken0.allowance(e, user, e.msg.sender) == 0;

    mathint balanceDebt_before = shareDebtToken1.balanceOf(e, user);
    mathint balanceCol_before = shareCollateralToken0.balanceOf(e, user);
    mathint balancePro_before = shareProtectedCollateralToken0.balanceOf(e, user);
        calldataarg args;
        f(e, args);
    mathint balanceDebt_after = shareDebtToken1.balanceOf(e, user);
    mathint balanceCol_after = shareCollateralToken0.balanceOf(e, user);
    mathint balancePro_after = shareProtectedCollateralToken0.balanceOf(e, user);

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
rule RA_assets_values_depend_on_shares_balances_only(env e, address user, method f) filtered{f -> !f.isView} {
    SafeAssumptions(e);
    /// No accrual of interest - we have proven that the assets value are conserved under interest accrual.
    require silo0.getSiloDataInterestRateTimestamp() == e.block.timestamp;

    SiloSolvencyLib.LtvData data_before = getAssetsDataForLtvCalculations(e, user);
    mathint balanceDebt_before = shareDebtToken1.balanceOf(e, user);
    mathint balanceCol_before = shareCollateralToken0.balanceOf(e, user);
    mathint balancePro_before = shareProtectedCollateralToken0.balanceOf(e, user);
        calldataarg args;
        f(e, args);
    SiloSolvencyLib.LtvData data_after = getAssetsDataForLtvCalculations(e, user);
    mathint balanceDebt_after = shareDebtToken1.balanceOf(e, user);
    mathint balanceCol_after = shareCollateralToken0.balanceOf(e, user);
    mathint balancePro_after = shareProtectedCollateralToken0.balanceOf(e, user);

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
    require shareDebtToken0.balanceOf(e, user2) == 0;

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
        e, shareDebtToken0.balanceOf(e, borrower2), ISilo.AssetType.Debt
    );

    repay(e, amount, borrower1) at initState;
    repay@withrevert(e, amount, borrower2) at initState;

    /// If the repaid amount is less than the borrower's debt then the operation must succeed.
    assert (amount <= borrower2_debt && borrower2 !=0) => !lastReverted;
}

/// @title An immediate withdraw after deposit by the same actor of the same amount must succeed.
rule RA_can_withdraw_after_deposit(env e) {
    SafeAssumptions(e);

    uint256 amount;
    require silo0.total(ISilo.AssetType.Protected) + silo0.total(ISilo.AssetType.Collateral) + amount <= max_uint128;
    require silo1.total(ISilo.AssetType.Protected) + silo1.total(ISilo.AssetType.Collateral) + amount <= max_uint128;
    
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
    require silo0.total(ISilo.AssetType.Protected) + silo0.total(ISilo.AssetType.Collateral) + amount <= max_uint128;
    require silo1.total(ISilo.AssetType.Protected) + silo1.total(ISilo.AssetType.Collateral) + amount <= max_uint128;
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