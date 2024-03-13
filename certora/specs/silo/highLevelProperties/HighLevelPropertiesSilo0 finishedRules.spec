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
