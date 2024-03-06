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
}

// holds
// https://prover.certora.com/output/6893/20a758fc0ac0435aad00e5081a794670/?anonymousKey=39aa24009ab8f114e45fb1de0c6e16ca9292df0f
rule HLP_integrityOfDeposit(env e, address receiver)
{
    completeSiloSetupEnv(e);
    requireDebtToken0TotalAndBalancesIntegrity();
    totalSupplyMoreThanBalance(receiver);
    
    uint256 assets;
    mathint balanceCollateralBefore = shareCollateralToken0.balanceOf(receiver);
    //require balanceCollateralBefore <= 2^100; 
    
    mathint shares = deposit(e, assets, receiver);
    //require shares <= 2^100; 
    mathint balanceCollateralAfter = shareCollateralToken0.balanceOf(receiver);  
   
    assert balanceCollateralAfter == balanceCollateralBefore + shares;
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
}
