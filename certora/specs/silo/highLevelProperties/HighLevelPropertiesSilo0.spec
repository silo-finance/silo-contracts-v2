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

use rule mulDiv_axioms_test;

// checks that if I mint X shares for Y assets, it's not possible to
// get X shares for <Y assets via two mints.
// same as HLP_mint_breakingUpNotBeneficial_full but only checks one side of the condition.
rule HLP_mint_breakingUpNotBeneficial_full3(env e, address receiver)
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

    assert !(diffCollateraBrokenUp >= diffCollateraCombined && 
        diffProtectedBrokenUp >= diffProtectedCombined && 
        diffTokenBrokenUp > diffTokenCombined);
}

// the same as above but without the bound of 1 in the assert
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

rule HLP_maxWithdraw_preserved_after_collateral_transition(env e, address user) 
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(user);
    totalSupplyMoreThanBalance(e.msg.sender);

    /// Invariants to prove
    require silo0.total(ISilo.AssetType.Protected) ==0 <=> shareProtectedCollateralToken0.totalSupply() == 0;
    require silo0.total(ISilo.AssetType.Collateral) ==0 <=> shareCollateralToken0.totalSupply() == 0;
    require silo1.total(ISilo.AssetType.Protected) ==0 <=> shareProtectedCollateralToken1.totalSupply() == 0;
    require silo1.total(ISilo.AssetType.Collateral) ==0 <=> shareCollateralToken1.totalSupply() == 0;

    uint256 maxAssets_before = maxWithdraw(e, user);
        uint256 shares;
        address owner;
        ISilo.AssetType type;
        transitionCollateral(e, shares, owner, type);
    uint256 maxAssets_after = maxWithdraw(e, user);

    assert maxAssets_after - maxAssets_before <= 2;
    assert maxAssets_after - maxAssets_before >= -2;
}

rule HLP_withdraw_breakingUpNotBeneficial(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    uint256 assets1;
    uint256 assets2;
    uint256 assetsSum;
    require assetsSum == require_uint256(assets1 + assets2);

    mathint balanceTokenBefore = token0.balanceOf(receiver);
    mathint balanceSharesBefore = shareDebtToken0.balanceOf(receiver);
    mathint balanceCollateralBefore = shareCollateralToken0.balanceOf(receiver);
    mathint balanceProtectedCollateralBefore = shareProtectedCollateralToken0.balanceOf(receiver);

    storage init = lastStorage;
    ISilo.AssetType anyType;
    
    withdraw(e, assetsSum, receiver, receiver, anyType);
    mathint balanceTokenAfterSum = token0.balanceOf(receiver);
    mathint balanceSharesAfterSum = shareDebtToken0.balanceOf(receiver);
    mathint balanceCollateralAfterSum = shareCollateralToken0.balanceOf(receiver);
    mathint balanceProtectedCollateralAfterSum = shareProtectedCollateralToken0.balanceOf(receiver);
    
    withdraw(e, assets1, receiver, receiver, anyType) at init;
    mathint balanceTokenAfter1 = token0.balanceOf(receiver);
    mathint balanceSharesAfter1 = shareDebtToken0.balanceOf(receiver);
    mathint balanceCollateralAfter1 = shareCollateralToken0.balanceOf(receiver);
    mathint balanceProtectedCollateralAfter1 = shareProtectedCollateralToken0.balanceOf(receiver);

    withdraw(e, assets2, receiver, receiver, anyType);
    mathint balanceTokenAfter1_2 = token0.balanceOf(receiver);
    mathint balanceSharesAfter1_2 = shareDebtToken0.balanceOf(receiver);
    mathint balanceCollateralAfter1_2 = shareCollateralToken0.balanceOf(receiver);
    mathint balanceProtectedCollateralAfter1_2 = shareProtectedCollateralToken0.balanceOf(receiver);

    assert balanceTokenAfter1_2 <= balanceTokenAfterSum;
    assert balanceSharesAfter1_2 >= balanceSharesAfterSum;
    assert balanceCollateralAfter1_2 <= balanceCollateralAfterSum;
    assert balanceProtectedCollateralAfter1_2 <= balanceProtectedCollateralAfterSum;

    satisfy balanceCollateralAfter1_2 >= balanceCollateralAfterSum;
    satisfy balanceProtectedCollateralAfter1_2 <= balanceProtectedCollateralAfterSum;
    satisfy balanceSharesAfter1_2 <= balanceSharesAfterSum;
}

rule HLP_borrow_breakingUpNotBeneficial(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    uint256 assets1;
    uint256 assets2;
    uint256 assetsSum;
    require assetsSum == require_uint256(assets1 + assets2);

    mathint balanceTokenBefore = token0.balanceOf(receiver);
    mathint balanceSharesBefore = shareDebtToken0.balanceOf(receiver);
    mathint balanceCollateralBefore = shareCollateralToken0.balanceOf(receiver);
    mathint balanceProtectedCollateralBefore = shareProtectedCollateralToken0.balanceOf(receiver);

    storage init = lastStorage;
    
    borrow(e, assetsSum, receiver, receiver);
    mathint balanceTokenAfterSum = token0.balanceOf(receiver);
    mathint balanceSharesAfterSum = shareDebtToken0.balanceOf(receiver);
    mathint balanceCollateralAfterSum = shareCollateralToken0.balanceOf(receiver);
    mathint balanceProtectedCollateralAfterSum = shareProtectedCollateralToken0.balanceOf(receiver);
    
    borrow(e, assets1, receiver, receiver) at init;
    mathint balanceTokenAfter1 = token0.balanceOf(receiver);
    mathint balanceSharesAfter1 = shareDebtToken0.balanceOf(receiver);
    mathint balanceCollateralAfter1 = shareCollateralToken0.balanceOf(receiver);
    mathint balanceProtectedCollateralAfter1 = shareProtectedCollateralToken0.balanceOf(receiver);

    borrow(e, assets2, receiver, receiver);
    mathint balanceTokenAfter1_2 = token0.balanceOf(receiver);
    mathint balanceSharesAfter1_2 = shareDebtToken0.balanceOf(receiver);
    mathint balanceCollateralAfter1_2 = shareCollateralToken0.balanceOf(receiver);
    mathint balanceProtectedCollateralAfter1_2 = shareProtectedCollateralToken0.balanceOf(receiver);

    assert balanceTokenAfter1_2 <= balanceTokenAfterSum;
    assert balanceSharesAfter1_2 >= balanceSharesAfterSum;
    assert balanceCollateralAfter1_2 <= balanceCollateralAfterSum;
    assert balanceProtectedCollateralAfter1_2 <= balanceProtectedCollateralAfterSum;

    satisfy balanceCollateralAfter1_2 >= balanceCollateralAfterSum;
    satisfy balanceProtectedCollateralAfter1_2 <= balanceProtectedCollateralAfterSum;
    satisfy balanceSharesAfter1_2 <= balanceSharesAfterSum;
}

rule HLP_borrowShares_breakingUpNotBeneficial(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    uint256 shares2;
    uint256 shares1;
    uint256 sharesSum;
    require sharesSum == require_uint256(shares1 + shares2);

    mathint balanceTokenBefore = token0.balanceOf(receiver);
    mathint balanceSharesBefore = shareDebtToken0.balanceOf(receiver);
    mathint balanceCollateralBefore = shareCollateralToken0.balanceOf(receiver);
    mathint balanceProtectedCollateralBefore = shareProtectedCollateralToken0.balanceOf(receiver);

    storage init = lastStorage;
    
    borrowShares(e, sharesSum, receiver, receiver);
    mathint balanceTokenAfterSum = token0.balanceOf(receiver);
    mathint balanceSharesAfterSum = shareDebtToken0.balanceOf(receiver);
    mathint balanceCollateralAfterSum = shareCollateralToken0.balanceOf(receiver);
    mathint balanceProtectedCollateralAfterSum = shareProtectedCollateralToken0.balanceOf(receiver);
    
    borrowShares(e, shares1, receiver, receiver) at init;
    mathint balanceTokenAfter1 = token0.balanceOf(receiver);
    mathint balanceSharesAfter1 = shareDebtToken0.balanceOf(receiver);
    mathint balanceCollateralAfter1 = shareCollateralToken0.balanceOf(receiver);
    mathint balanceProtectedCollateralAfter1 = shareProtectedCollateralToken0.balanceOf(receiver);

    borrowShares(e, shares2, receiver, receiver);
    mathint balanceTokenAfter1_2 = token0.balanceOf(receiver);
    mathint balanceSharesAfter1_2 = shareDebtToken0.balanceOf(receiver);
    mathint balanceCollateralAfter1_2 = shareCollateralToken0.balanceOf(receiver);
    mathint balanceProtectedCollateralAfter1_2 = shareProtectedCollateralToken0.balanceOf(receiver);

    assert balanceTokenAfter1_2 <= balanceTokenAfterSum;
    assert balanceSharesAfter1_2 >= balanceSharesAfterSum;
    assert balanceCollateralAfter1_2 <= balanceCollateralAfterSum;
    assert balanceProtectedCollateralAfter1_2 <= balanceProtectedCollateralAfterSum;

    satisfy balanceCollateralAfter1_2 >= balanceCollateralAfterSum;
    satisfy balanceProtectedCollateralAfter1_2 <= balanceProtectedCollateralAfterSum;
    satisfy balanceSharesAfter1_2 <= balanceSharesAfterSum;
}

rule HLP_repayShares_breakingUpNotBeneficial(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    uint256 shares2;
    uint256 shares1;
    uint256 sharesSum;
    require sharesSum == require_uint256(shares1 + shares2);

    mathint balanceTokenBefore = token0.balanceOf(receiver);
    mathint balanceSharesBefore = shareDebtToken0.balanceOf(receiver);
    mathint balanceCollateralBefore = shareCollateralToken0.balanceOf(receiver);
    mathint balanceProtectedCollateralBefore = shareProtectedCollateralToken0.balanceOf(receiver);

    storage init = lastStorage;
    
    repayShares(e, sharesSum, receiver);
    mathint balanceTokenAfterSum = token0.balanceOf(receiver);
    mathint balanceSharesAfterSum = shareDebtToken0.balanceOf(receiver);
    mathint balanceCollateralAfterSum = shareCollateralToken0.balanceOf(receiver);
    mathint balanceProtectedCollateralAfterSum = shareProtectedCollateralToken0.balanceOf(receiver);
    
    repayShares(e, shares1, receiver) at init;
    mathint balanceTokenAfter1 = token0.balanceOf(receiver);
    mathint balanceSharesAfter1 = shareDebtToken0.balanceOf(receiver);
    mathint balanceCollateralAfter1 = shareCollateralToken0.balanceOf(receiver);
    mathint balanceProtectedCollateralAfter1 = shareProtectedCollateralToken0.balanceOf(receiver);

    repayShares(e, shares2, receiver);
    mathint balanceTokenAfter1_2 = token0.balanceOf(receiver);
    mathint balanceSharesAfter1_2 = shareDebtToken0.balanceOf(receiver);
    mathint balanceCollateralAfter1_2 = shareCollateralToken0.balanceOf(receiver);
    mathint balanceProtectedCollateralAfter1_2 = shareProtectedCollateralToken0.balanceOf(receiver);

    assert balanceTokenAfter1_2 <= balanceTokenAfterSum;
    assert balanceSharesAfter1_2 >= balanceSharesAfterSum;
    assert balanceCollateralAfter1_2 <= balanceCollateralAfterSum;
    assert balanceProtectedCollateralAfter1_2 <= balanceProtectedCollateralAfterSum;

    satisfy balanceCollateralAfter1_2 >= balanceCollateralAfterSum;
    satisfy balanceProtectedCollateralAfter1_2 <= balanceProtectedCollateralAfterSum;
    satisfy balanceSharesAfter1_2 <= balanceSharesAfterSum;
}


rule HLP_transition_collateral_preserves_solvent(env e, address user) 
{
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

    require
    (silo0.total(ISilo.AssetType.Protected) >= shareProtectedCollateralToken0.totalSupply()) &&
    (silo0.total(ISilo.AssetType.Collateral) >= shareCollateralToken0.totalSupply()) &&
    (silo0.total(ISilo.AssetType.Debt) >= shareDebtToken0.totalSupply());

    require isSolvent(e, user);
        uint256 shares;
        address owner;
        ISilo.AssetType type;
        transitionCollateral(e, shares, owner, type);
    assert isSolvent(e, user);
}