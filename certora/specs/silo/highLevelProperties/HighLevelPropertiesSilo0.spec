import "../_common/CompleteSiloSetup.spec";
import "../_common/IsSiloFunction.spec";
import "../_common/SiloMethods.spec";
import "../_common/Helpers.spec";
import "../_common/CommonSummarizations.spec";
import "../../_simplifications/Oracle_quote_one.spec";
import "../../_simplifications/Silo_isSolvent_ghost.spec";
import "../../_simplifications/SimplifiedGetCompoundInterestRateAndUpdate.spec";


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
}

/*
    Breaking-up larger withdraw to two smaller ones doesn't benefit the user.
*/
rule HLP_withdraw_breakingUpNotBeneficial(env e, address receiver, address owner)
{
    completeSiloSetupEnv(e);
    requireDebtToken0TotalAndBalancesIntegrity();
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(owner);
    uint256 assets1;
    uint256 assets2;
    uint256 assetsSum;
    require assetsSum == require_uint256(assets1 + assets2);

    mathint balanceSharesBefore = shareDebtToken0.balanceOf(receiver);
    mathint balanceCollateralBefore = shareCollateralToken0.balanceOf(receiver);
    mathint balanceProtectedCollateralBefore = shareProtectedCollateralToken0.balanceOf(receiver);

    storage init = lastStorage;

    ISilo.AssetType anyType;
    withdraw(e, assetsSum, receiver, owner, anyType);
    mathint balanceSharesAfterSum = shareDebtToken0.balanceOf(receiver);
    mathint balanceCollateralAfterSum = shareCollateralToken0.balanceOf(receiver);
    mathint balanceProtectedCollateralAfterSum = shareProtectedCollateralToken0.balanceOf(receiver);
    
    withdraw(e, assets1, receiver, owner, anyType) at init;
    mathint balanceSharesAfter1 = shareDebtToken0.balanceOf(receiver);
    mathint balanceCollateralAfter1 = shareCollateralToken0.balanceOf(receiver);
    mathint balanceProtectedCollateralAfter1 = shareProtectedCollateralToken0.balanceOf(receiver);

    withdraw(e, assets2, receiver, owner, anyType);
    mathint balanceSharesAfter1_2 = shareDebtToken0.balanceOf(receiver);
    mathint balanceCollateralAfter1_2 = shareCollateralToken0.balanceOf(receiver);
    mathint balanceProtectedCollateralAfter1_2 = shareProtectedCollateralToken0.balanceOf(receiver);

    assert balanceSharesAfter1_2 <= balanceSharesAfterSum;
    assert balanceCollateralAfter1_2 <= balanceCollateralAfterSum;
    assert balanceProtectedCollateralAfter1_2 <= balanceProtectedCollateralAfterSum;
}

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
    
    assert differsAtMost(balanceCollateralAfter, balanceCollateralBefore, 100);
    assert differsAtMost(balanceCollateralAfter, balanceCollateralBefore, 10);
    assert differsAtMost(balanceCollateralAfter, balanceCollateralBefore, 1);
}
