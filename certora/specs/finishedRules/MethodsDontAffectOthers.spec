import "../_common/CompleteSiloSetup.spec";
import "../_common/IsSiloFunction.spec";
import "../_common/SiloMethods.spec";
import "../_common/Helpers.spec";
import "../_common/CommonSummarizations.spec";
import "../_simplifications/Oracle_quote_one.spec";
import "../_simplifications/Silo_isSolvent_ghost.spec";
import "../_simplifications/SimplifiedGetCompoundInterestRateAndUpdate.spec";

// satisfy statements provide a witness - a proof that the rule is not vacuous

rule HLP_DepositDoesntAffectOthers(env e, address receiver)
{
    address other;
    require other != receiver;
    require other != e.msg.sender;
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);
    totalSupplyMoreThanBalance(other);
    
    mathint balanceTokenBefore = token0.balanceOf(other);
    mathint balanceSharesBefore = shareDebtToken0.balanceOf(other);
    mathint balanceCollateralBefore = shareCollateralToken0.balanceOf(other);
    mathint balanceProtectedCollateralBefore = shareProtectedCollateralToken0.balanceOf(other);
    
    uint256 assets;
    mathint shares = deposit(e, assets, receiver);
        
    mathint balanceTokenAfter = token0.balanceOf(other);
    mathint balanceSharesAfter = shareDebtToken0.balanceOf(other);
    mathint balanceCollateralAfter = shareCollateralToken0.balanceOf(other);
    mathint balanceProtectedCollateralAfter = shareProtectedCollateralToken0.balanceOf(other);
   
    assert balanceTokenBefore == balanceTokenAfter;
    assert balanceSharesBefore == balanceSharesAfter;
    assert balanceCollateralBefore == balanceCollateralAfter;
    assert balanceProtectedCollateralBefore == balanceProtectedCollateralAfter;

    satisfy balanceTokenBefore == balanceTokenAfter;
    satisfy balanceSharesBefore == balanceSharesAfter;
    satisfy balanceCollateralBefore == balanceCollateralAfter;
    satisfy balanceProtectedCollateralBefore == balanceProtectedCollateralAfter;
}

rule HLP_MintDoesntAffectOthers(env e, address receiver)
{
    address other;
    require other != receiver;
    require other != e.msg.sender;
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);
    totalSupplyMoreThanBalance(other);
    
    mathint balanceTokenBefore = token0.balanceOf(other);
    mathint balanceSharesBefore = shareDebtToken0.balanceOf(other);
    mathint balanceCollateralBefore = shareCollateralToken0.balanceOf(other);
    mathint balanceProtectedCollateralBefore = shareProtectedCollateralToken0.balanceOf(other);
    
    uint256 shares;
    mathint assets = mint(e, shares, receiver);
        
    mathint balanceTokenAfter = token0.balanceOf(other);
    mathint balanceSharesAfter = shareDebtToken0.balanceOf(other);
    mathint balanceCollateralAfter = shareCollateralToken0.balanceOf(other);
    mathint balanceProtectedCollateralAfter = shareProtectedCollateralToken0.balanceOf(other);
   
    assert balanceTokenBefore == balanceTokenAfter;
    assert balanceSharesBefore == balanceSharesAfter;
    assert balanceCollateralBefore == balanceCollateralAfter;
    assert balanceProtectedCollateralBefore == balanceProtectedCollateralAfter;

    satisfy balanceTokenBefore == balanceTokenAfter;
    satisfy balanceSharesBefore == balanceSharesAfter;
    satisfy balanceCollateralBefore == balanceCollateralAfter;
    satisfy balanceProtectedCollateralBefore == balanceProtectedCollateralAfter;
}

rule HLP_RedeemDoesntAffectOthers(env e, address receiver)
{
    address other;
    require other != receiver;
    require other != e.msg.sender;
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);
    totalSupplyMoreThanBalance(other);
    
    mathint balanceTokenBefore = token0.balanceOf(other);
    mathint balanceSharesBefore = shareDebtToken0.balanceOf(other);
    mathint balanceCollateralBefore = shareCollateralToken0.balanceOf(other);
    mathint balanceProtectedCollateralBefore = shareProtectedCollateralToken0.balanceOf(other);
    
    uint256 shares;
    mathint assets = redeem(e, shares, receiver, e.msg.sender);
        
    mathint balanceTokenAfter = token0.balanceOf(other);
    mathint balanceSharesAfter = shareDebtToken0.balanceOf(other);
    mathint balanceCollateralAfter = shareCollateralToken0.balanceOf(other);
    mathint balanceProtectedCollateralAfter = shareProtectedCollateralToken0.balanceOf(other);
   
    assert balanceTokenBefore == balanceTokenAfter;
    assert balanceSharesBefore == balanceSharesAfter;
    assert balanceCollateralBefore == balanceCollateralAfter;
    assert balanceProtectedCollateralBefore == balanceProtectedCollateralAfter;

    satisfy balanceTokenBefore == balanceTokenAfter;
    satisfy balanceSharesBefore == balanceSharesAfter;
    satisfy balanceCollateralBefore == balanceCollateralAfter;
    satisfy balanceProtectedCollateralBefore == balanceProtectedCollateralAfter;
}

rule HLP_WithdrawDoesntAffectOthers(env e, address receiver)
{
    address other;
    require other != receiver;
    require other != e.msg.sender;
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);
    totalSupplyMoreThanBalance(other);
    
    mathint balanceTokenBefore = token0.balanceOf(other);
    mathint balanceSharesBefore = shareDebtToken0.balanceOf(other);
    mathint balanceCollateralBefore = shareCollateralToken0.balanceOf(other);
    mathint balanceProtectedCollateralBefore = shareProtectedCollateralToken0.balanceOf(other);
    
    uint256 assets;
    mathint shares = withdraw(e, assets, receiver, e.msg.sender);
        
    mathint balanceTokenAfter = token0.balanceOf(other);
    mathint balanceSharesAfter = shareDebtToken0.balanceOf(other);
    mathint balanceCollateralAfter = shareCollateralToken0.balanceOf(other);
    mathint balanceProtectedCollateralAfter = shareProtectedCollateralToken0.balanceOf(other);
   
    assert balanceTokenBefore == balanceTokenAfter;
    assert balanceSharesBefore == balanceSharesAfter;
    assert balanceCollateralBefore == balanceCollateralAfter;
    assert balanceProtectedCollateralBefore == balanceProtectedCollateralAfter;

    satisfy balanceTokenBefore == balanceTokenAfter;
    satisfy balanceSharesBefore == balanceSharesAfter;
    satisfy balanceCollateralBefore == balanceCollateralAfter;
    satisfy balanceProtectedCollateralBefore == balanceProtectedCollateralAfter;
}

rule HLP_transitionCollateralDoesntAffectOthers(env e, address receiver)
{
    address other;
    require other != receiver;
    require other != e.msg.sender;
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);
    totalSupplyMoreThanBalance(other);
    
    mathint balanceTokenBefore = token0.balanceOf(other);
    mathint balanceSharesBefore = shareDebtToken0.balanceOf(other);
    mathint balanceCollateralBefore = shareCollateralToken0.balanceOf(other);
    mathint balanceProtectedCollateralBefore = shareProtectedCollateralToken0.balanceOf(other);

    ISilo.CollateralType anyType;    
    uint256 shares;
    mathint assets = transitionCollateral(e, shares, e.msg.sender, anyType);
        
    mathint balanceTokenAfter = token0.balanceOf(other);
    mathint balanceSharesAfter = shareDebtToken0.balanceOf(other);
    mathint balanceCollateralAfter = shareCollateralToken0.balanceOf(other);
    mathint balanceProtectedCollateralAfter = shareProtectedCollateralToken0.balanceOf(other);
   
    assert balanceTokenBefore == balanceTokenAfter;
    assert balanceSharesBefore == balanceSharesAfter;
    assert balanceCollateralBefore == balanceCollateralAfter;
    assert balanceProtectedCollateralBefore == balanceProtectedCollateralAfter;

    satisfy balanceTokenBefore == balanceTokenAfter;
    satisfy balanceSharesBefore == balanceSharesAfter;
    satisfy balanceCollateralBefore == balanceCollateralAfter;
    satisfy balanceProtectedCollateralBefore == balanceProtectedCollateralAfter;
}

rule HLP_borrowDoesntAffectOthers(env e, address receiver)
{
    address other;
    require other != receiver;
    require other != e.msg.sender;
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);
    totalSupplyMoreThanBalance(other);
    
    mathint balanceTokenBefore = token0.balanceOf(other);
    mathint balanceSharesBefore = shareDebtToken0.balanceOf(other);
    mathint balanceCollateralBefore = shareCollateralToken0.balanceOf(other);
    mathint balanceProtectedCollateralBefore = shareProtectedCollateralToken0.balanceOf(other);
  
    bool sameAsset;
    uint256 assets;
    mathint shares = borrow(e, assets, receiver, e.msg.sender, sameAsset);
        
    mathint balanceTokenAfter = token0.balanceOf(other);
    mathint balanceSharesAfter = shareDebtToken0.balanceOf(other);
    mathint balanceCollateralAfter = shareCollateralToken0.balanceOf(other);
    mathint balanceProtectedCollateralAfter = shareProtectedCollateralToken0.balanceOf(other);
   
    assert balanceTokenBefore == balanceTokenAfter;
    assert balanceSharesBefore == balanceSharesAfter;
    assert balanceCollateralBefore == balanceCollateralAfter;
    assert balanceProtectedCollateralBefore == balanceProtectedCollateralAfter;

    satisfy balanceTokenBefore == balanceTokenAfter;
    satisfy balanceSharesBefore == balanceSharesAfter;
    satisfy balanceCollateralBefore == balanceCollateralAfter;
    satisfy balanceProtectedCollateralBefore == balanceProtectedCollateralAfter;
}

rule HLP_repayDoesntAffectOthers(env e, address receiver)
{
    address other;
    require other != receiver;
    require other != e.msg.sender;
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);
    totalSupplyMoreThanBalance(other);
    
    mathint balanceTokenBefore = token0.balanceOf(other);
    mathint balanceSharesBefore = shareDebtToken0.balanceOf(other);
    mathint balanceCollateralBefore = shareCollateralToken0.balanceOf(other);
    mathint balanceProtectedCollateralBefore = shareProtectedCollateralToken0.balanceOf(other);
  
    uint256 assets;
    mathint shares = repay(e, assets, e.msg.sender);
        
    mathint balanceTokenAfter = token0.balanceOf(other);
    mathint balanceSharesAfter = shareDebtToken0.balanceOf(other);
    mathint balanceCollateralAfter = shareCollateralToken0.balanceOf(other);
    mathint balanceProtectedCollateralAfter = shareProtectedCollateralToken0.balanceOf(other);
   
    assert balanceTokenBefore == balanceTokenAfter;
    assert balanceSharesBefore == balanceSharesAfter;
    assert balanceCollateralBefore == balanceCollateralAfter;
    assert balanceProtectedCollateralBefore == balanceProtectedCollateralAfter;

    satisfy balanceTokenBefore == balanceTokenAfter;
    satisfy balanceSharesBefore == balanceSharesAfter;
    satisfy balanceCollateralBefore == balanceCollateralAfter;
    satisfy balanceProtectedCollateralBefore == balanceProtectedCollateralAfter;
}

rule HLP_borrowSharesDoesntAffectOthers(env e, address receiver)
{
    address other;
    require other != receiver;
    require other != e.msg.sender;
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);
    totalSupplyMoreThanBalance(other);
    
    mathint balanceTokenBefore = token0.balanceOf(other);
    mathint balanceSharesBefore = shareDebtToken0.balanceOf(other);
    mathint balanceCollateralBefore = shareCollateralToken0.balanceOf(other);
    mathint balanceProtectedCollateralBefore = shareProtectedCollateralToken0.balanceOf(other);
  
    bool sameAsset;
    uint256 shares;
    mathint assets = borrowShares(e, shares, receiver, e.msg.sender, sameAsset);
        
    mathint balanceTokenAfter = token0.balanceOf(other);
    mathint balanceSharesAfter = shareDebtToken0.balanceOf(other);
    mathint balanceCollateralAfter = shareCollateralToken0.balanceOf(other);
    mathint balanceProtectedCollateralAfter = shareProtectedCollateralToken0.balanceOf(other);
   
    assert balanceTokenBefore == balanceTokenAfter;
    assert balanceSharesBefore == balanceSharesAfter;
    assert balanceCollateralBefore == balanceCollateralAfter;
    assert balanceProtectedCollateralBefore == balanceProtectedCollateralAfter;

    satisfy balanceTokenBefore == balanceTokenAfter;
    satisfy balanceSharesBefore == balanceSharesAfter;
    satisfy balanceCollateralBefore == balanceCollateralAfter;
    satisfy balanceProtectedCollateralBefore == balanceProtectedCollateralAfter;
}

rule HLP_repaySharesDoesntAffectOthers(env e, address receiver)
{
    address other;
    require other != receiver;
    require other != e.msg.sender;
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);
    totalSupplyMoreThanBalance(other);
    
    mathint balanceTokenBefore = token0.balanceOf(other);
    mathint balanceSharesBefore = shareDebtToken0.balanceOf(other);
    mathint balanceCollateralBefore = shareCollateralToken0.balanceOf(other);
    mathint balanceProtectedCollateralBefore = shareProtectedCollateralToken0.balanceOf(other);
  
    uint256 shares;
    mathint assets = repayShares(e, shares, e.msg.sender);
        
    mathint balanceTokenAfter = token0.balanceOf(other);
    mathint balanceSharesAfter = shareDebtToken0.balanceOf(other);
    mathint balanceCollateralAfter = shareCollateralToken0.balanceOf(other);
    mathint balanceProtectedCollateralAfter = shareProtectedCollateralToken0.balanceOf(other);
   
    assert balanceTokenBefore == balanceTokenAfter;
    assert balanceSharesBefore == balanceSharesAfter;
    assert balanceCollateralBefore == balanceCollateralAfter;
    assert balanceProtectedCollateralBefore == balanceProtectedCollateralAfter;

    satisfy balanceTokenBefore == balanceTokenAfter;
    satisfy balanceSharesBefore == balanceSharesAfter;
    satisfy balanceCollateralBefore == balanceCollateralAfter;
    satisfy balanceProtectedCollateralBefore == balanceProtectedCollateralAfter;
}