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



