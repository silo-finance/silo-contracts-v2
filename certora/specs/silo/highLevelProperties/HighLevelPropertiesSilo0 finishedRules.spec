import "../_common/CompleteSiloSetup.spec";
import "../_common/IsSiloFunction.spec";
import "../_common/SiloMethods.spec";
import "../_common/Helpers.spec";
import "../_common/CommonSummarizations.spec";
//import "../../_simplifications/Oracle_quote_one.spec";
import "../../_simplifications/priceOracle.spec";
//import "../../_simplifications/Silo_isSolvent_ghost.spec";
//import "../../_simplifications/SiloSolvencyLib.spec";
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

// checks that two mints never give better tradeoff than one
// violated. E.g. mint(13) costs 4, mint(4);mint(10) costs 1+3=4
// https://prover.certora.com/output/6893/30faf353b80b4e41bd8de18b7ce080f7/?anonymousKey=a9260fb2c1753b137aae9218621c8267f88b0e0d
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
        diffTokenBrokenUp > diffTokenCombined);

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
