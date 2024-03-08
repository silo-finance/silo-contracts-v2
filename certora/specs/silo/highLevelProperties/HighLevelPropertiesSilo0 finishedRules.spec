import "../_common/CompleteSiloSetup.spec";
import "../_common/IsSiloFunction.spec";
import "../_common/SiloMethods.spec";
import "../_common/Helpers.spec";
import "../_common/CommonSummarizations.spec";
import "../../_simplifications/Oracle_quote_one.spec";
import "../../_simplifications/Silo_isSolvent_ghost.spec";
import "../../_simplifications/SimplifiedGetCompoundInterestRateAndUpdate.spec";


/*
    Breaking-up larger deposit to two smaller ones doesn't benefit the user.
    holds 
    https://prover.certora.com/output/6893/9b6394efb2e1451880822abad6d2f699/?anonymousKey=6fd6cb0f42c1fd2bda3878e00f46361945bf28f1
*/
rule HLP_deposit_breakingUpNotBeneficial_collateral(
    env e,
    address receiver) 
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    requireDebtToken0TotalAndBalancesIntegrity();
    uint256 assets1;
    uint256 assets2;
    uint256 assetsSum;
    require assetsSum == require_uint256(assets1 + assets2);
    mathint balanceCollateralBefore = shareCollateralToken0.balanceOf(receiver);
    storage init = lastStorage;
    ISilo.AssetType anyType;
    
    deposit(e, assetsSum, receiver, anyType);
    mathint balanceCollateralAfterSum = shareCollateralToken0.balanceOf(receiver);
    
    deposit(e, assets1, receiver, anyType) at init;
    mathint balanceCollateralAfter1 = shareCollateralToken0.balanceOf(receiver);
    deposit(e, assets2, receiver, anyType);
    mathint balanceCollateralAfter1_2 = shareCollateralToken0.balanceOf(receiver);
    
    assert balanceCollateralAfter1_2 <= balanceCollateralAfterSum;
    satisfy balanceCollateralAfter1_2 <= balanceCollateralAfterSum;
}

// holds
// https://prover.certora.com/output/6893/9c5256b31d9f4b17b364ebd5fc764c0c/?anonymousKey=37960b61607aa6b87c9755fad0d2e3d1cdb7dfbb
rule HLP_deposit_breakingUpNotBeneficial_protectedCollateral(
    env e,
    address receiver) 
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    requireDebtToken0TotalAndBalancesIntegrity();
    uint256 assets1;
    uint256 assets2;
    uint256 assetsSum;
    require assetsSum == require_uint256(assets1 + assets2);
    mathint balanceProtectedCollateralBefore = shareProtectedCollateralToken0.balanceOf(receiver);
    storage init = lastStorage;
    ISilo.AssetType anyType;
    
    deposit(e, assetsSum, receiver, anyType);
    mathint balanceProtectedCollateralAfterSum = shareProtectedCollateralToken0.balanceOf(receiver);
    
    deposit(e, assets1, receiver, anyType) at init;
    mathint balanceProtectedCollateralAfter1 = shareProtectedCollateralToken0.balanceOf(receiver);
    deposit(e, assets2, receiver, anyType);
    mathint balanceProtectedCollateralAfter1_2 = shareProtectedCollateralToken0.balanceOf(receiver);
    
    assert balanceProtectedCollateralAfter1_2 <= balanceProtectedCollateralAfterSum;
    satisfy balanceProtectedCollateralAfter1_2 <= balanceProtectedCollateralAfterSum;
}

// holds
// https://prover.certora.com/output/6893/a8822df55134416bba8a500158862a7a/?anonymousKey=378450aa5259da444a7956248209e9f7916dc4af
rule HLP_redeem_breakingUpNotBeneficial(env e, address receiver, address owner)
{
    completeSiloSetupEnv(e);
    requireDebtToken0TotalAndBalancesIntegrity();
    uint256 assets1;
    uint256 assets2;
    uint256 assetsSum;
    require assetsSum == require_uint256(assets1 + assets2);

    mathint balanceSharesBefore = shareDebtToken0.balanceOf(receiver);
    mathint balanceCollateralBefore = shareCollateralToken0.balanceOf(receiver);
    mathint balanceProtectedCollateralBefore = shareProtectedCollateralToken0.balanceOf(receiver);

    storage init = lastStorage;

    ISilo.AssetType anyType;
    redeem(e, assetsSum, receiver, owner, anyType);
    mathint balanceSharesAfterSum = shareDebtToken0.balanceOf(receiver);
    mathint balanceCollateralAfterSum = shareCollateralToken0.balanceOf(receiver);
    mathint balanceProtectedCollateralAfterSum = shareProtectedCollateralToken0.balanceOf(receiver);
    
    redeem(e, assets1, receiver, owner, anyType) at init;
    mathint balanceSharesAfter1 = shareDebtToken0.balanceOf(receiver);
    mathint balanceCollateralAfter1 = shareCollateralToken0.balanceOf(receiver);
    mathint balanceProtectedCollateralAfter1 = shareProtectedCollateralToken0.balanceOf(receiver);

    redeem(e, assets2, receiver, owner, anyType);
    mathint balanceSharesAfter1_2 = shareDebtToken0.balanceOf(receiver);
    mathint balanceCollateralAfter1_2 = shareCollateralToken0.balanceOf(receiver);
    mathint balanceProtectedCollateralAfter1_2 = shareProtectedCollateralToken0.balanceOf(receiver);

    assert balanceSharesAfter1_2 <= balanceSharesAfterSum;
    assert balanceCollateralAfter1_2 <= balanceCollateralAfterSum;
    assert balanceProtectedCollateralAfter1_2 <= balanceProtectedCollateralAfterSum;

    satisfy balanceSharesAfter1_2 <= balanceSharesAfterSum;
    satisfy balanceCollateralAfter1_2 <= balanceCollateralAfterSum;
    satisfy balanceProtectedCollateralAfter1_2 <= balanceProtectedCollateralAfterSum;
}

// holds
// https://prover.certora.com/output/6893/7b3e0d066d204b21be2e94da31c11426/?anonymousKey=2f7c2f549fe8908fa305b50cf3c22da6fdbdbd4c
rule HLP_integrityOfDeposit(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    
    uint256 assets;
    mathint balanceCollateralBefore = shareCollateralToken0.balanceOf(receiver);
    mathint balanceTokenBefore = token0.balanceOf(e.msg.sender);  
    
    mathint shares = deposit(e, assets, receiver);
    mathint balanceCollateralAfter = shareCollateralToken0.balanceOf(receiver);  
    mathint balanceTokenAfter = token0.balanceOf(e.msg.sender);  

    assert balanceCollateralAfter == balanceCollateralBefore + shares;
    satisfy balanceCollateralAfter == balanceCollateralBefore + shares;
    assert balanceTokenAfter == balanceTokenBefore - assets;
    satisfy balanceTokenAfter == balanceTokenBefore - assets;
}

// holds 
// https://prover.certora.com/output/6893/ca2e8fdc835340c4a7fc2ba97092f21a/?anonymousKey=8dc2bfc842b1659011bb0c6534843683daaa8f78
rule HLP_integrityOfMint(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    
    uint256 shares;
    mathint balanceCollateralBefore = shareCollateralToken0.balanceOf(receiver);
    mathint balanceTokenBefore = token0.balanceOf(e.msg.sender);  
        
    mathint assets = mint(e, shares, receiver);
    mathint balanceCollateralAfter = shareCollateralToken0.balanceOf(receiver);  
    mathint balanceTokenAfter = token0.balanceOf(e.msg.sender);  
   
    assert balanceCollateralAfter == balanceCollateralBefore + shares;
    satisfy balanceCollateralAfter == balanceCollateralBefore + shares;
    assert balanceTokenAfter == balanceTokenBefore - assets;
    satisfy balanceTokenAfter == balanceTokenBefore - assets;
}

// holds
// https://prover.certora.com/output/6893/23e6c7a9f5574fbc9545ad732360ce65/?anonymousKey=8bc60c373fee4ce8935b34dd2196e0df1bfa94f6
rule HLP_depositCollateralUpdatesOnlyRecepient(env e, address receiver)
{
    address other;
    require other != receiver;
    completeSiloSetupEnv(e);
    requireDebtToken0TotalAndBalancesIntegrity();
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(other);
    
    uint256 assets;
    mathint balanceCollateralBeforeOther = shareCollateralToken0.balanceOf(other);
    
    mathint shares = deposit(e, assets, receiver);
    mathint balanceCollateralAfterOther = shareCollateralToken0.balanceOf(other);  
   
    assert balanceCollateralBeforeOther == balanceCollateralAfterOther;
    satisfy balanceCollateralBeforeOther == balanceCollateralAfterOther;
}

// holds
// https://prover.certora.com/output/6893/effe608ee2d84cf59c4f721df7bd2fd8/?anonymousKey=c84e3a163a6e284bef0e2407411818dbf1316c26
rule HLP_depositAndInverse(env e, address receiver)
{
    completeSiloSetupEnv(e);
    requireDebtToken0TotalAndBalancesIntegrity();
    totalSupplyMoreThanBalance(receiver);
    
    uint256 assets;
    mathint balanceCollateralBefore = shareCollateralToken0.balanceOf(receiver);
    mathint sharesD = deposit(e, assets, receiver);
    mathint sharesW = withdraw(e, assets, receiver, receiver);
    
    mathint balanceCollateralAfter = shareCollateralToken0.balanceOf(receiver);  
    
    assert differsAtMost(balanceCollateralAfter, balanceCollateralBefore, 1);
    satisfy differsAtMost(balanceCollateralAfter, balanceCollateralBefore, 1);
}

// holds
// https://prover.certora.com/output/6893/b3a6a4c01c0d47cfaeab657ec1fddfdb/?anonymousKey=4b0e515cae5549782924823fc1e584160da9073c
rule HLP_mintAndInverse(env e, address receiver)
{
    completeSiloSetupEnv(e);
    requireDebtToken0TotalAndBalancesIntegrity();
    totalSupplyMoreThanBalance(receiver);
    
    uint256 shares;
    mathint balanceCollateralBefore = shareCollateralToken0.balanceOf(receiver);
    mathint assetsM = mint(e, shares, receiver);
    mathint assetsR = redeem(e, shares, receiver, receiver);
    
    mathint balanceCollateralAfter = shareCollateralToken0.balanceOf(receiver);  
    
    assert balanceCollateralAfter == balanceCollateralBefore;
    satisfy balanceCollateralAfter == balanceCollateralBefore;
}

// holds
// https://prover.certora.com/output/6893/a883accfe908407dbece26fad0cc28a9/?anonymousKey=c5e531139686606822c837171aa31d22ae8d78ba
rule HLP_borrowSharesAndInverse(env e, address receiver)
{
    completeSiloSetupEnv(e);
    requireDebtToken0TotalAndBalancesIntegrity();
    totalSupplyMoreThanBalance(receiver);
    
    uint256 shares;
    mathint debtBefore = shareDebtToken0.balanceOf(receiver);
    mathint assetsB = borrowShares(e, shares, receiver, receiver);
    mathint assetsR = repayShares(e, shares, receiver);
    
    mathint debtAfter = shareDebtToken0.balanceOf(receiver);  
    
    assert debtAfter == debtBefore;
    satisfy debtAfter == debtBefore;
}
