import "../_common/CompleteSiloSetup.spec";
import "../_common/IsSiloFunction.spec";
import "../_common/SiloMethods.spec";
import "../_common/Helpers.spec";
import "../_common/CommonSummarizations.spec";
import "../../_simplifications/Oracle_quote_one.spec";
import "../../_simplifications/Silo_isSolvent_ghost.spec";
import "../../_simplifications/SimplifiedGetCompoundInterestRateAndUpdate.spec";


/*
    Breaking-up larger mint to two smaller ones doesn't benefit the user.
    holds
    https://prover.certora.com/output/6893/c0e41ae8e7bd47149d6c9cbdd9ce4295/?anonymousKey=937b56fbb72f8b0b2293f90d539860b2d976da67
*/
rule HLP_mint_breakingUpNotBeneficial(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    uint256 shares1;
    uint256 shares2;
    uint256 sharesSum;
    require sharesSum == require_uint256(shares1 + shares2);

    mathint balanceTokenBefore = token0.balanceOf(receiver);
    mathint balanceSharesBefore = shareDebtToken0.balanceOf(receiver);
    mathint balanceCollateralBefore = shareCollateralToken0.balanceOf(receiver);
    mathint balanceProtectedCollateralBefore = shareProtectedCollateralToken0.balanceOf(receiver);

    storage init = lastStorage;
    ISilo.AssetType anyType;
    
    mint(e, sharesSum, receiver, anyType);
    mathint balanceTokenAfterSum = token0.balanceOf(receiver);
    mathint balanceSharesAfterSum = shareDebtToken0.balanceOf(receiver);
    mathint balanceCollateralAfterSum = shareCollateralToken0.balanceOf(receiver);
    mathint balanceProtectedCollateralAfterSum = shareProtectedCollateralToken0.balanceOf(receiver);
    
    mint(e, shares1, receiver, anyType) at init;
    mathint balanceTokenAfter1 = token0.balanceOf(receiver);
    mathint balanceSharesAfter1 = shareDebtToken0.balanceOf(receiver);
    mathint balanceCollateralAfter1 = shareCollateralToken0.balanceOf(receiver);
    mathint balanceProtectedCollateralAfter1 = shareProtectedCollateralToken0.balanceOf(receiver);

    mint(e, shares2, receiver, anyType);
    mathint balanceTokenAfter1_2 = token0.balanceOf(receiver);
    mathint balanceSharesAfter1_2 = shareDebtToken0.balanceOf(receiver);
    mathint balanceCollateralAfter1_2 = shareCollateralToken0.balanceOf(receiver);
    mathint balanceProtectedCollateralAfter1_2 = shareProtectedCollateralToken0.balanceOf(receiver);

    assert balanceSharesAfter1_2 <= balanceSharesAfterSum;
    assert balanceCollateralAfter1_2 <= balanceCollateralAfterSum;
    assert balanceProtectedCollateralAfter1_2 <= balanceProtectedCollateralAfterSum;

    satisfy balanceCollateralAfter1_2 <= balanceCollateralAfterSum;
    satisfy balanceProtectedCollateralAfter1_2 <= balanceProtectedCollateralAfterSum;
    satisfy balanceSharesAfter1_2 <= balanceSharesAfterSum;
}

rule HLP_mint_breakingUpNotBeneficial_full(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);

    uint256 shares;
    uint256 sharesAttempt1; uint256 sharesAttempt2;

    mathint balanceTokenBefore = token0.balanceOf(e.msg.sender);
    mathint balanceCollateralBefore = shareCollateralToken0.balanceOf(receiver);
    mathint balanceProtectedCollateralBefore = shareProtectedCollateralToken0.balanceOf(receiver);

    storage init = lastStorage;
    ISilo.AssetType anyType;
    
    mint(e, shares, receiver, anyType);
        mathint balanceTokenAfterSum = token0.balanceOf(e.msg.sender);
        mathint balanceCollateralAfterSum = shareCollateralToken0.balanceOf(receiver);
        mathint balanceProtectedCollateralAfterSum = shareProtectedCollateralToken0.balanceOf(receiver);
    
    mint(e, sharesAttempt1, receiver, anyType) at init;
        mathint balanceTokenAfter1 = token0.balanceOf(e.msg.sender);
        mathint balanceCollateralAfter1 = shareCollateralToken0.balanceOf(receiver);
        mathint balanceProtectedCollateralAfter1 = shareProtectedCollateralToken0.balanceOf(receiver);

    mint(e, sharesAttempt2, receiver, anyType);
        mathint balanceTokenAfter1_2 = token0.balanceOf(e.msg.sender);
        mathint balanceCollateralAfter1_2 = shareCollateralToken0.balanceOf(receiver);
        mathint balanceProtectedCollateralAfter1_2 = shareProtectedCollateralToken0.balanceOf(receiver);

    mathint diffTokenCombined = balanceTokenAfterSum - balanceTokenBefore;
    mathint diffCollateraCombined = balanceCollateralAfterSum - balanceCollateralBefore;
    mathint diffProtectedCombined = balanceProtectedCollateralAfterSum - balanceProtectedCollateralBefore;

    mathint diffTokenBrokenUp = balanceTokenAfter1_2 - balanceTokenBefore;
    mathint diffCollateraBrokenUp = balanceCollateralAfter1_2 - balanceCollateralBefore;
    mathint diffProtectedBrokenUp = balanceProtectedCollateralAfter1_2 - balanceProtectedCollateralBefore;

    assert !(diffTokenBrokenUp >= diffTokenCombined  && 
        (diffCollateraBrokenUp > diffCollateraCombined + 1 || diffProtectedBrokenUp > diffProtectedCombined + 1));

    assert !(diffCollateraBrokenUp >= diffCollateraCombined && 
        diffProtectedBrokenUp >= diffProtectedCombined && 
        diffTokenBrokenUp >diffTokenCombined);

}

rule HLP_mint_breakingUpNotBeneficial_full2(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);

    uint256 shares;
    uint256 sharesAttempt1; uint256 sharesAttempt2;

    mathint balanceTokenBefore = token0.balanceOf(e.msg.sender);
    mathint balanceCollateralBefore = shareCollateralToken0.balanceOf(receiver);
    mathint balanceProtectedCollateralBefore = shareProtectedCollateralToken0.balanceOf(receiver);

    storage init = lastStorage;
    ISilo.AssetType anyType;
    
    mint(e, shares, receiver, anyType);
        mathint balanceTokenAfterSum = token0.balanceOf(e.msg.sender);
        mathint balanceCollateralAfterSum = shareCollateralToken0.balanceOf(receiver);
        mathint balanceProtectedCollateralAfterSum = shareProtectedCollateralToken0.balanceOf(receiver);
    
    mint(e, sharesAttempt1, receiver, anyType) at init;
        mathint balanceTokenAfter1 = token0.balanceOf(e.msg.sender);
        mathint balanceCollateralAfter1 = shareCollateralToken0.balanceOf(receiver);
        mathint balanceProtectedCollateralAfter1 = shareProtectedCollateralToken0.balanceOf(receiver);

    mint(e, sharesAttempt2, receiver, anyType);
        mathint balanceTokenAfter1_2 = token0.balanceOf(e.msg.sender);
        mathint balanceCollateralAfter1_2 = shareCollateralToken0.balanceOf(receiver);
        mathint balanceProtectedCollateralAfter1_2 = shareProtectedCollateralToken0.balanceOf(receiver);

    mathint diffTokenCombined = balanceTokenAfterSum - balanceTokenBefore;
    mathint diffCollateraCombined = balanceCollateralAfterSum - balanceCollateralBefore;
    mathint diffProtectedCombined = balanceProtectedCollateralAfterSum - balanceProtectedCollateralBefore;

    mathint diffTokenBrokenUp = balanceTokenAfter1_2 - balanceTokenBefore;
    mathint diffCollateraBrokenUp = balanceCollateralAfter1_2 - balanceCollateralBefore;
    mathint diffProtectedBrokenUp = balanceProtectedCollateralAfter1_2 - balanceProtectedCollateralBefore;

    assert !(diffTokenBrokenUp >= diffTokenCombined  && 
        (diffCollateraBrokenUp > diffCollateraCombined || diffProtectedBrokenUp > diffProtectedCombined));

    assert !(diffCollateraBrokenUp >= diffCollateraCombined && 
        diffProtectedBrokenUp >= diffProtectedCombined && 
        diffTokenBrokenUp > diffTokenCombined);

}

rule HLP_borrowAndInverse(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    
    uint256 assets;
    mathint debtBefore = shareDebtToken0.balanceOf(receiver);
    mathint sharesB = borrow(e, assets, receiver, receiver);
    mathint debtAfterB = shareDebtToken0.balanceOf(receiver);
    mathint sharesR = repay(e, assets, receiver);
    mathint debtAfterR = shareDebtToken0.balanceOf(receiver);
    
    mathint debtAfter = shareDebtToken0.balanceOf(receiver);  
    
    assert differsAtMost(debtAfter, debtBefore, 100);
    assert differsAtMost(debtAfter, debtBefore, 10);
    assert differsAtMost(debtAfter, debtBefore, 1);
    satisfy debtAfter == debtBefore;
}

rule HLP_transitionColateral_additivity_revert(env e, address receiver)
{
    completeSiloSetupEnv(e);
    //requireDebtToken0TotalAndBalancesIntegrity();
    totalSupplyMoreThanBalance(receiver);
    
    uint256 shares1; uint256 shares2;
    uint256 sharesSum;
    require sharesSum == require_uint256(shares1 + shares2);
    require sharesSum < 2^100;
    ISilo.AssetType anyType;

    storage init = lastStorage;
    transitionCollateral@withrevert(e, sharesSum, receiver, anyType); 
    bool sumReverted = lastReverted;
    
    transitionCollateral@withrevert(e, shares1, receiver, anyType) at init;
    bool reverted1 = lastReverted;
    transitionCollateral@withrevert(e, shares2, receiver, anyType);
    bool reverted2 = lastReverted;

    assert sumReverted == (reverted1 || reverted2);
}

rule HLP_transitionColateral_additivity(env e, address receiver)
{
    //require receiver == e.msg.sender;
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    
    uint256 shares1; uint256 shares2;
    uint256 sharesSum;
    require sharesSum == require_uint256(shares1 + shares2);
    ISilo.AssetType anyType;
    mathint balanceCollateralBefore = shareCollateralToken0.balanceOf(receiver);
    mathint balanceProtectedCollateralBefore = shareProtectedCollateralToken0.balanceOf(receiver);

    storage init = lastStorage;
    transitionCollateral(e, sharesSum, receiver, anyType); 
    mathint balanceCollateralSum = shareCollateralToken0.balanceOf(receiver);
    mathint balanceProtectedCollateralSum = shareProtectedCollateralToken0.balanceOf(receiver);
    
    transitionCollateral(e, shares1, receiver, anyType) at init;
    mathint balanceCollateral1 = shareCollateralToken0.balanceOf(receiver);
    mathint balanceProtectedCollateral1 = shareProtectedCollateralToken0.balanceOf(receiver);
    transitionCollateral(e, shares2, receiver, anyType);
    mathint balanceCollateral1_2 = shareCollateralToken0.balanceOf(receiver);
    mathint balanceProtectedCollateral1_2 = shareProtectedCollateralToken0.balanceOf(receiver);

    //assert balanceCollateralSum + balanceProtectedCollateralSum >= balanceCollateral1_2 + balanceProtectedCollateral1_2;
    assert balanceCollateralSum >= balanceCollateral1_2;    
    assert balanceProtectedCollateralSum >= balanceProtectedCollateral1_2;    

    //satisfy balanceCollateralSum + balanceProtectedCollateralSum >= balanceCollateral1_2 + balanceProtectedCollateral1_2;
}

rule HLP_Mint2RedeemNotProfitable(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);
    
    mathint balanceCollateralBefore = shareCollateralToken0.balanceOf(receiver);
    mathint balanceTokenBefore = token0.balanceOf(e.msg.sender);    

    uint256 assets1; uint256 assets2; uint256 shares;
    mathint sharesM1 = mint(e, assets1, receiver);
    mathint balanceCollateralM1 = shareCollateralToken0.balanceOf(receiver);  
    mathint balanceTokenM1 = token0.balanceOf(e.msg.sender);    

    mathint sharesM2 = mint(e, assets2, receiver);
    mathint balanceCollateralM2 = shareCollateralToken0.balanceOf(receiver);  
    mathint balanceTokenM2 = token0.balanceOf(e.msg.sender);    
   
    mathint assetsR = redeem(e, shares, receiver, receiver);
    mathint balanceCollateralR = shareCollateralToken0.balanceOf(receiver);  
    mathint balanceTokenR = token0.balanceOf(e.msg.sender);    
   
    assert balanceCollateralR >= balanceCollateralBefore => balanceTokenR <= balanceTokenBefore;
}

rule HLP_Mint2Redeem2NotProfitable(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);
    
    mathint balanceCollateralBefore = shareCollateralToken0.balanceOf(receiver);
    mathint balanceTokenBefore = token0.balanceOf(e.msg.sender);    

    uint256 assets1; uint256 assets2; uint256 shares1; uint256 shares2;
    mathint sharesM1 = mint(e, assets1, receiver);
    mathint balanceCollateralM1 = shareCollateralToken0.balanceOf(receiver);  
    mathint balanceTokenM1 = token0.balanceOf(e.msg.sender);    

    mathint sharesM2 = mint(e, assets2, receiver);
    mathint balanceCollateralM2 = shareCollateralToken0.balanceOf(receiver);  
    mathint balanceTokenM2 = token0.balanceOf(e.msg.sender);    
   
    mathint assetsR1 = redeem(e, shares1, receiver, receiver);
    mathint balanceCollateralR1 = shareCollateralToken0.balanceOf(receiver);  
    mathint balanceTokenR1 = token0.balanceOf(e.msg.sender);    
    
    mathint assetsR2 = redeem(e, shares2, receiver, receiver);
    mathint balanceCollateralR2 = shareCollateralToken0.balanceOf(receiver);  
    mathint balanceTokenR2 = token0.balanceOf(e.msg.sender);    
   
    assert balanceCollateralR2 >= balanceCollateralBefore => balanceTokenR2 <= balanceTokenBefore;
}

rule HLP_MintRedeem2NotProfitable(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);
    
    mathint balanceCollateralBefore = shareCollateralToken0.balanceOf(receiver);
    mathint balanceTokenBefore = token0.balanceOf(e.msg.sender);    

    uint256 assets1; uint256 assets2; uint256 shares1; uint256 shares2;
    mathint sharesM1 = mint(e, assets1, receiver);
    mathint balanceCollateralM1 = shareCollateralToken0.balanceOf(receiver);  
    mathint balanceTokenM1 = token0.balanceOf(e.msg.sender);    

    //mathint sharesM2 = mint(e, assets2, receiver);
    //mathint balanceCollateralM2 = shareCollateralToken0.balanceOf(receiver);  
    //mathint balanceTokenM2 = token0.balanceOf(e.msg.sender);    
   
    mathint assetsR1 = redeem(e, shares1, receiver, receiver);
    mathint balanceCollateralR1 = shareCollateralToken0.balanceOf(receiver);  
    mathint balanceTokenR1 = token0.balanceOf(e.msg.sender);    
    
    mathint assetsR2 = redeem(e, shares2, receiver, receiver);
    mathint balanceCollateralR2 = shareCollateralToken0.balanceOf(receiver);  
    mathint balanceTokenR2 = token0.balanceOf(e.msg.sender);    
   
    assert balanceCollateralR2 >= balanceCollateralBefore => balanceTokenR2 <= balanceTokenBefore;
}

// for testing only
rule testCollateralScale(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);
    
    mathint balanceCollateralBefore = shareCollateralToken0.balanceOf(receiver);
    mathint balanceProtectedCollateralBefore = shareProtectedCollateralToken0.balanceOf(receiver);
    mathint balanceTokenBefore = token0.balanceOf(e.msg.sender);    

    storage init = lastStorage;
    uint256 assets;
    ISilo.AssetType typeC = ISilo.AssetType.Collateral;
    mathint collateralShares = deposit(e, assets, receiver, typeC);
    
    ISilo.AssetType typeP = ISilo.AssetType.Protected;
    mathint protectedCollateralShares = deposit(e, assets, receiver, typeP) at init;

    satisfy collateralShares != protectedCollateralShares;
}

// holds
// https://prover.certora.com/output/6893/2ff8676c6e1142f8ae409ca94991b06b/?anonymousKey=22d2387bfb082e9c8d098dc21bdc15b9b38702c2
rule HLP_DepositRedeemNotProfitable(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);
    
    mathint balanceCollateralBefore = shareCollateralToken0.balanceOf(receiver);
    mathint balanceTokenBefore = token0.balanceOf(e.msg.sender);    

    uint256 assets; 
    mathint sharesM1 = deposit(e, assets, receiver);
    mathint balanceCollateralM1 = shareCollateralToken0.balanceOf(receiver);  
    mathint balanceTokenM1 = token0.balanceOf(e.msg.sender);    

    uint256 shares;
    mathint assetsR = redeem(e, shares, e.msg.sender, receiver);
    mathint balanceCollateralR = shareCollateralToken0.balanceOf(receiver);  
    mathint balanceTokenR = token0.balanceOf(e.msg.sender);    
   
    assert balanceCollateralR > balanceCollateralBefore => balanceTokenR < balanceTokenBefore;
    assert balanceTokenR > balanceTokenBefore => balanceCollateralR < balanceCollateralBefore;
}

rule HLP_MintWithdrawNotProfitable(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);
    
    mathint balanceCollateralBefore = shareCollateralToken0.balanceOf(receiver);
    mathint balanceTokenBefore = token0.balanceOf(e.msg.sender);    

    uint256 shares; 
    mathint assetsM = mint(e, shares, receiver);
    mathint balanceCollateralM = shareCollateralToken0.balanceOf(receiver);  
    mathint balanceTokenM = token0.balanceOf(e.msg.sender);    

    uint256 assets;
    mathint sharesW = withdraw(e, assets, e.msg.sender, receiver);
    mathint balanceCollateralW = shareCollateralToken0.balanceOf(receiver);  
    mathint balanceTokenW = token0.balanceOf(e.msg.sender);    
   
    assert balanceCollateralW > balanceCollateralBefore => balanceTokenW < balanceTokenBefore;
    assert balanceTokenW > balanceTokenBefore => balanceCollateralW < balanceCollateralBefore;

    satisfy balanceCollateralW > balanceCollateralBefore => balanceTokenW < balanceTokenBefore;
    satisfy balanceTokenW > balanceTokenBefore => balanceCollateralW < balanceCollateralBefore;
}

rule HLP_AssetsPerShareNondecreasing(env e, method f)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(e.msg.sender);
    sharesToAssetsNotTooHigh(e, 2);
    requireTokensTotalAndBalanceIntegrity();

    mathint totalCollateralAssetsB; mathint totalProtectedAssetsB;
    totalCollateralAssetsB, totalProtectedAssetsB = getCollateralAndProtectedAssets(e);  
    mathint totalSumColateralB = totalCollateralAssetsB + totalProtectedAssetsB;
    mathint totalSharesB = shareCollateralToken0.totalSupply();
    mathint totalProtectedSharesB = shareProtectedCollateralToken0.totalSupply();

    calldataarg args;
    f(e, args);
    
    mathint totalCollateralAssetsA; mathint totalProtectedAssetsA;
    totalCollateralAssetsA, totalProtectedAssetsA = getCollateralAndProtectedAssets(e);  
    mathint totalSumColateralA = totalCollateralAssetsA + totalProtectedAssetsA;
    mathint totalSharesA = shareCollateralToken0.totalSupply();
    mathint totalProtectedSharesA = shareProtectedCollateralToken0.totalSupply();
    
    require totalSharesB > 0;
    require totalSharesA > 0;

    assert totalCollateralAssetsB * totalSharesA <= totalCollateralAssetsA * totalSharesB +  totalSharesA * totalSharesB;

    /*
    assert differsAtMost(totalProtectedAssetsB * totalProtectedSharesA,
        totalProtectedAssetsA * totalProtectedSharesB, totalProtectedSharesA * totalProtectedSharesB);
    assert differsAtMost(totalSumColateralB * totalSumSharesA,
        totalSumColateralA * totalSumSharesB, totalSumSharesA * totalSumSharesB);
    */
    //assert totalCollateralAssetsB * totalSharesA <= totalCollateralAssetsA * totalSharesB;
    //assert totalProtectedAssetsB * totalProtectedSharesA <= totalProtectedAssetsA * totalProtectedSharesB;
    //assert totalSumColateralB * totalSumSharesA <= totalSumColateralA * totalSumSharesB;
}

rule HLP_OthersCantDecreaseMyRedeem(env e, env eOther, method f)
    filtered { f -> !f.isView }
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(e.msg.sender);
    completeSiloSetupEnv(eOther);
    totalSupplyMoreThanBalance(eOther.msg.sender);
    require e.msg.sender != eOther.msg.sender;
    sharesToAssetsNotTooHigh(e, 2);
    sharesToAssetsNotTooHigh(eOther, 2);

    storage init = lastStorage;
    uint256 shares;
    mathint assetsReceived = redeem(e, shares, e.msg.sender, e.msg.sender);
    
    calldataarg args;
    f(eOther, args) at init;
    mathint assetsReceived2 = redeem(e, shares, e.msg.sender, e.msg.sender);

    assert assetsReceived2 >= assetsReceived;
}

rule HLP_OthersCantDecreaseMyRedeem_viaDeposit(env e, env eOther)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(e.msg.sender);
    completeSiloSetupEnv(eOther);
    totalSupplyMoreThanBalance(eOther.msg.sender);
    require e.msg.sender != eOther.msg.sender;
    sharesToAssetsNotTooHigh(e, 2);
    sharesToAssetsNotTooHigh(eOther, 2);

    storage init = lastStorage;
    uint256 shares;
    mathint assetsReceived = redeem(e, shares, e.msg.sender, e.msg.sender);
    
    uint256 assets;
    address receiver;
    deposit(eOther, assets, receiver) at init;
    mathint assetsReceived2 = redeem(e, shares, e.msg.sender, e.msg.sender);

    assert assetsReceived2 >= assetsReceived;
}


rule HLP_OthersCantDecreaseMyRedeem_viaWithdraw(env e, env eOther)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(e.msg.sender);
    completeSiloSetupEnv(eOther);
    totalSupplyMoreThanBalance(eOther.msg.sender);
    require e.msg.sender != eOther.msg.sender;
    sharesToAssetsNotTooHigh(e, 2);
    sharesToAssetsNotTooHigh(eOther, 2);

    storage init = lastStorage;
    uint256 shares;
    mathint assetsReceived = redeem(e, shares, e.msg.sender, e.msg.sender);
    
    uint256 assets;
    address receiver;
    totalSupplyMoreThanBalance(eOther.msg.sender);
    withdraw(eOther, assets, receiver, receiver) at init;
    mathint assetsReceived2 = redeem(e, shares, e.msg.sender, e.msg.sender);

    assert assetsReceived2 >= assetsReceived;
}


