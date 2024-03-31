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

use rule assetsToSharesAndBackAxiom;
use rule mulDiv_axioms_test;

// A user cannot withdraw anything after withdrawing whole balance.
// holds
// https://prover.certora.com/output/6893/6ebdfe9df3f04b4b887bdb1c5372637c/?anonymousKey=af1886c64a28e05f1ee50a3c98745a75596a38ad
rule RA_Silo_no_withdraw_after_withdrawing_all(env e, address user)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(user);
    totalSupplyMoreThanBalance(e.msg.sender);
    

    uint256 balanceCollateralBefore = shareCollateralToken0.balanceOf(user);
    uint256 balanceProtectedCollateralBefore = shareProtectedCollateralToken0.balanceOf(user);

    storage init = lastStorage;
    mathint assets = redeem(e, balanceCollateralBefore, user, user, ISilo.AssetType.Collateral);
    uint256 shares;
    redeem@withrevert(e, shares, user, user, ISilo.AssetType.Collateral);
    assert lastReverted;

    mathint assets2 = redeem(e, balanceProtectedCollateralBefore, user, user, ISilo.AssetType.Protected) at init;
    uint256 shares2;
    redeem@withrevert(e, shares2, user, user, ISilo.AssetType.Protected);
    assert lastReverted;

}

// A user should not be able to fully repay a loan with less amount than he borrowed.
rule RA_Silo_no_negative_interest_for_loan(env e, address user)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(user);
    totalSupplyMoreThanBalance(e.msg.sender);
    
    uint256 assetsBorrowed;
    mathint debt = borrow(e, assetsBorrowed, user, e.msg.sender);
    uint256 assetsRepayed;
    mathint debtPaid = repay(e, assetsRepayed, e.msg.sender);
    
    assert assetsBorrowed > assetsRepayed => debt > debtPaid;
}

// A user should not be able to fully repay a loan with less amount than he borrowed.
// Even if there's a method called in between.
rule RA_Silo_no_negative_interest_for_loan_Param(env e, address user, method f)
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

// A user should not be able to deposit an asset that he borrowed in the Silo.
// violated
// No longer applicable in current version
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

// A user has no debt after being repaid with max shares amount.
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

// User should not be able to borrow more than maxBorrow().
rule RA_silo_cant_borrow_more_than_max(env e, address borrower) {
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(borrower);

    require silo0.total(ISilo.AssetType.Protected) + silo0.total(ISilo.AssetType.Collateral) <= max_uint256;
    require silo1.total(ISilo.AssetType.Protected) + silo1.total(ISilo.AssetType.Collateral) <= max_uint256;
    require shareProtectedCollateralToken0.totalSupply() + shareCollateralToken0.totalSupply() <= max_uint256;
    require shareProtectedCollateralToken1.totalSupply() + shareCollateralToken1.totalSupply() <= max_uint256;
    requireProtectedToken0TotalAndBalancesIntegrity();
    requireCollateralToken0TotalAndBalancesIntegrity();
    requireDebtToken0TotalAndBalancesIntegrity();
    requireProtectedToken1TotalAndBalancesIntegrity();
    requireCollateralToken1TotalAndBalancesIntegrity();
    requireDebtToken1TotalAndBalancesIntegrity();
    requireInvariant RA_no_collateral_assets_no_debt_assets();
    requireInvariant RA_more_assets_than_shares();

    uint256 maxAssets = maxBorrow(e, borrower);
    uint256 assets; address receiver; 
    borrow(e, assets, receiver, borrower);

    assert assets <= maxAssets;
}

// User should not be able to borrow without collateral.
rule RA_silo_cant_borrow_without_collateral(env e, address borrower) {
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(borrower);

    require silo0.total(ISilo.AssetType.Protected) + silo0.total(ISilo.AssetType.Collateral) <= max_uint256;
    require silo1.total(ISilo.AssetType.Protected) + silo1.total(ISilo.AssetType.Collateral) <= max_uint256;
    require shareProtectedCollateralToken0.totalSupply() + shareCollateralToken0.totalSupply() <= max_uint256;
    require shareProtectedCollateralToken1.totalSupply() + shareCollateralToken1.totalSupply() <= max_uint256;
    requireProtectedToken0TotalAndBalancesIntegrity();
    requireCollateralToken0TotalAndBalancesIntegrity();
    requireDebtToken0TotalAndBalancesIntegrity();
    requireProtectedToken1TotalAndBalancesIntegrity();
    requireCollateralToken1TotalAndBalancesIntegrity();
    requireDebtToken1TotalAndBalancesIntegrity();
    requireInvariant RA_no_collateral_assets_no_debt_assets();

    uint256 collateralShares = shareCollateralToken1.balanceOf(borrower);
    uint256 protectedCollateralShares = shareProtectedCollateralToken1.balanceOf(borrower);
    uint256 maxAssets = maxBorrow(e, borrower);
    assert collateralShares == 0 && protectedCollateralShares ==0 => maxAssets == 0;
}

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
            completeSiloSetupEnv(e);
            requireProtectedToken0TotalAndBalancesIntegrity();
            requireCollateralToken0TotalAndBalancesIntegrity();
            requireDebtToken0TotalAndBalancesIntegrity();
            requireProtectedToken1TotalAndBalancesIntegrity();
            requireCollateralToken1TotalAndBalancesIntegrity();
            requireDebtToken1TotalAndBalancesIntegrity();
        }
    }

/// https://prover.certora.com/output/41958/af1acf321bf044c6ab813b243ae08ddd/?anonymousKey=3a898b5d61e73bebff14c4ad88d7f26912b8fbd4
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
    Need to make sure no debt shares are available without collateral shares.
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
            completeSiloSetupEnv(e);
            totalSupplyMoreThanBalance(e.msg.sender);
            requireProtectedToken0TotalAndBalancesIntegrity();
            requireCollateralToken0TotalAndBalancesIntegrity();
            requireDebtToken0TotalAndBalancesIntegrity();
            requireProtectedToken1TotalAndBalancesIntegrity();
            requireCollateralToken1TotalAndBalancesIntegrity();
            requireDebtToken1TotalAndBalancesIntegrity();
            requireInvariant RA_zero_assets_iff_zero_shares();
            requireInvariant RA_no_collateral_assets_no_debt_assets();
        }
    }

rule RA_silo_solvent_after_repaying(env e, address borrower) {
    completeSiloSetupEnv(e);
    require silo0.getSiloDataInterestRateTimestamp() > 0;
    totalSupplyMoreThanBalance(borrower);
    totalSupplyMoreThanBalance(e.msg.sender);
    requireProtectedToken0TotalAndBalancesIntegrity();
    requireCollateralToken0TotalAndBalancesIntegrity();
    requireDebtToken0TotalAndBalancesIntegrity();
    requireProtectedToken1TotalAndBalancesIntegrity();
    requireCollateralToken1TotalAndBalancesIntegrity();
    requireDebtToken1TotalAndBalancesIntegrity();

    requireInvariant RA_more_assets_than_shares();

    require isSolvent(e, borrower);
        uint256 assets;
        repay(e, assets, borrower);
    assert isSolvent(e, borrower);
}

rule RA_silo_solvent_after_borrow(env e, address borrower) {
    completeSiloSetupEnv(e);
    require silo0.getSiloDataInterestRateTimestamp() > 0;
    totalSupplyMoreThanBalance(borrower);
    totalSupplyMoreThanBalance(e.msg.sender);
    requireProtectedToken0TotalAndBalancesIntegrity();
    requireCollateralToken0TotalAndBalancesIntegrity();
    requireDebtToken0TotalAndBalancesIntegrity();
    requireProtectedToken1TotalAndBalancesIntegrity();
    requireCollateralToken1TotalAndBalancesIntegrity();
    requireDebtToken1TotalAndBalancesIntegrity();
    requireInvariant RA_more_assets_than_shares();
    
    uint256 assets;
    address receiver;
    borrow(e, assets, receiver, borrower);
    assert isSolvent(e, borrower);
}

rule RA_user_cannot_lower_HF_of_another(env e, address user, method f) filtered{f -> !f.isView} {
    completeSiloSetupEnv(e);
    require silo0.getSiloDataInterestRateTimestamp() > 0;
    totalSupplyMoreThanBalance(user);
    totalSupplyMoreThanBalance(e.msg.sender);
    requireProtectedToken0TotalAndBalancesIntegrity();
    requireCollateralToken0TotalAndBalancesIntegrity();
    requireDebtToken0TotalAndBalancesIntegrity();
    requireProtectedToken1TotalAndBalancesIntegrity();
    requireCollateralToken1TotalAndBalancesIntegrity();
    requireDebtToken1TotalAndBalancesIntegrity();
    requireInvariant RA_more_assets_than_shares();
    require e.msg.sender != user;

    /// No accrual of interest
    require silo0.getSiloDataInterestRateTimestamp() == e.block.timestamp;
    /// No allowance
    require shareDebtToken0.allowance(e, user, e.msg.sender) == 0;
    require shareCollateralToken0.allowance(e, user, e.msg.sender) == 0;
    require shareProtectedCollateralToken0.allowance(e, user, e.msg.sender) == 0;

    mathint balanceDebt_before = shareDebtToken0.balanceOf(e, user);
    mathint balanceCol_before = shareCollateralToken0.balanceOf(e, user);
    mathint balancePro_before = shareProtectedCollateralToken0.balanceOf(e, user);
        calldataarg args;
        f(e, args);
    mathint balanceDebt_after = shareDebtToken0.balanceOf(e, user);
    mathint balanceCol_after = shareCollateralToken0.balanceOf(e, user);
    mathint balancePro_after = shareProtectedCollateralToken0.balanceOf(e, user);

    assert balanceDebt_before >= balanceDebt_after, "Debt balance cannot increase by other user";
    assert balanceCol_before <= balanceCol_after, "Collateral balance cannot decrease by other user";
    assert balancePro_before <= balancePro_after, "Protected balance cannot decrease by other user";
}

rule RA_LTV_depends_on_shares_balances_only(env e, address user, method f) filtered{f -> !f.isView} {
    completeSiloSetupEnv(e);
    require silo0.getSiloDataInterestRateTimestamp() > 0;
    totalSupplyMoreThanBalance(user);
    totalSupplyMoreThanBalance(e.msg.sender);
    requireProtectedToken0TotalAndBalancesIntegrity();
    requireCollateralToken0TotalAndBalancesIntegrity();
    requireDebtToken0TotalAndBalancesIntegrity();
    requireProtectedToken1TotalAndBalancesIntegrity();
    requireCollateralToken1TotalAndBalancesIntegrity();
    requireDebtToken1TotalAndBalancesIntegrity();
    requireInvariant RA_more_assets_than_shares();
    /// No accrual of interest
    require silo0.getSiloDataInterestRateTimestamp() == e.block.timestamp;

    uint256 ltv_before = getLTV(e, user);
    mathint balanceDebt_before = shareDebtToken0.balanceOf(e, user);
    mathint balanceCol_before = shareCollateralToken0.balanceOf(e, user);
    mathint balancePro_before = shareProtectedCollateralToken0.balanceOf(e, user);
        calldataarg args;
        f(e, args);
    uint256 ltv_after = getLTV(e, user);
    mathint balanceDebt_after = shareDebtToken0.balanceOf(e, user);
    mathint balanceCol_after = shareCollateralToken0.balanceOf(e, user);
    mathint balancePro_after = shareProtectedCollateralToken0.balanceOf(e, user);

    assert (
        balanceDebt_before == balanceDebt_after && 
        balanceCol_before == balanceCol_after &&
        balancePro_after == balancePro_before
    ) => ltv_after == ltv_before;
}