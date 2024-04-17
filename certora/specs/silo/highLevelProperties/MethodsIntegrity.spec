import "../_common/CompleteSiloSetup.spec";
import "../_common/IsSiloFunction.spec";
import "../_common/SiloMethods.spec";
import "../_common/Helpers.spec";
import "../_common/CommonSummarizations.spec";
import "../../_simplifications/Oracle_quote_one.spec";
import "../../_simplifications/Silo_isSolvent_ghost.spec";
import "../../_simplifications/SimplifiedGetCompoundInterestRateAndUpdate.spec";


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

    assert shares > 0;
    assert balanceCollateralAfter == balanceCollateralBefore + shares;
    satisfy balanceCollateralAfter == balanceCollateralBefore + shares;
    assert balanceTokenAfter == balanceTokenBefore - assets;
    satisfy balanceTokenAfter == balanceTokenBefore - assets;
}

// holds
// https://prover.certora.com/output/6893/5004415c5d1f412a87149b3dc5d30aa2/?anonymousKey=a6e1d304fb214e83a690497243a23faebea53bd2
rule HLP_integrityOfWithdraw(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    
    uint256 assets;
    mathint balanceCollateralBefore = shareCollateralToken0.balanceOf(receiver);
    mathint balanceTokenBefore = token0.balanceOf(receiver);    

    mathint shares = withdraw(e, assets, receiver, receiver);
    mathint balanceCollateralAfter = shareCollateralToken0.balanceOf(receiver);  
    mathint balanceTokenAfter = token0.balanceOf(receiver);
   
    assert balanceCollateralAfter == balanceCollateralBefore - shares;
    assert balanceTokenAfter == balanceTokenBefore + assets;
    satisfy balanceCollateralAfter == balanceCollateralBefore - shares;
    satisfy balanceTokenAfter == balanceTokenBefore + assets;
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
// https://prover.certora.com/output/6893/a6caffc038034717b762ba7a059b5f5f/?anonymousKey=501b833ea142883e27d15df11edaeec39a65af37
rule HLP_integrityOfRedeem(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    
    uint256 shares;
    mathint balanceCollateralBefore = shareCollateralToken0.balanceOf(receiver);
    mathint balanceTokenBefore = token0.balanceOf(receiver);  
        
    mathint assets = redeem(e, shares, receiver, receiver);
    mathint balanceCollateralAfter = shareCollateralToken0.balanceOf(receiver);  
    mathint balanceTokenAfter = token0.balanceOf(receiver);  
   
    assert balanceCollateralAfter == balanceCollateralBefore - shares;
    satisfy balanceCollateralAfter == balanceCollateralBefore - shares;
    assert balanceTokenAfter == balanceTokenBefore + assets;
    satisfy balanceTokenAfter == balanceTokenBefore + assets;
}

// holds
// https://prover.certora.com/output/6893/aa725d07720a46ccb2fd5c1a33991862/?anonymousKey=499a5a0078ba61e6578ce1460377a257371b9db3
rule HLP_integrityOfBorrowShares(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    
    uint256 shares;
    mathint balanceTokenBefore = token0.balanceOf(receiver);  
    mathint shareDebtTokenBefore = shareDebtToken0.balanceOf(receiver);  
       
    mathint assets = borrowShares(e, shares, receiver, receiver);
    mathint balanceTokenAfter = token0.balanceOf(receiver);  
    mathint shareDebtTokenAfter = shareDebtToken0.balanceOf(receiver);  
   
    assert balanceTokenAfter == balanceTokenBefore + assets;
    satisfy balanceTokenAfter == balanceTokenBefore + assets;

    assert shareDebtTokenAfter == shareDebtTokenBefore + shares;
    satisfy shareDebtTokenAfter == shareDebtTokenBefore + shares;
}

//holds
// https://prover.certora.com/output/6893/fec3898fc8b44cd3afc8785b15983974/?anonymousKey=80943c985d74b40e96bada86662e9bf0fdaa539e
rule HLP_integrityOfRepayShares(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    require receiver == e.msg.sender;

    uint256 shares;
    mathint balanceTokenBefore = token0.balanceOf(receiver);  
    mathint shareDebtTokenBefore = shareDebtToken0.balanceOf(receiver);  
       
    mathint assets = repayShares(e, shares, receiver);
    mathint balanceTokenAfter = token0.balanceOf(receiver);  
    mathint shareDebtTokenAfter = shareDebtToken0.balanceOf(receiver);  
   
    assert balanceTokenAfter == balanceTokenBefore - assets;
    satisfy balanceTokenAfter == balanceTokenBefore - assets;

    assert shareDebtTokenAfter == shareDebtTokenBefore - shares;
    satisfy shareDebtTokenAfter == shareDebtTokenBefore - shares;
}

// https://prover.certora.com/output/6893/fec3898fc8b44cd3afc8785b15983974/?anonymousKey=80943c985d74b40e96bada86662e9bf0fdaa539e
rule HLP_integrityOfBorrow(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    
    uint256 assets;
    mathint balanceTokenBefore = token0.balanceOf(receiver);  
    mathint shareDebtTokenBefore = shareDebtToken0.balanceOf(receiver);  
       
    mathint shares = borrow(e, assets, receiver, receiver);
    mathint balanceTokenAfter = token0.balanceOf(receiver);  
    mathint shareDebtTokenAfter = shareDebtToken0.balanceOf(receiver);  
   
    assert balanceTokenAfter == balanceTokenBefore + assets;
    satisfy balanceTokenAfter == balanceTokenBefore + assets;

    assert shareDebtTokenAfter == shareDebtTokenBefore + shares;
    satisfy shareDebtTokenAfter == shareDebtTokenBefore + shares;
}

// https://prover.certora.com/output/6893/fec3898fc8b44cd3afc8785b15983974/?anonymousKey=80943c985d74b40e96bada86662e9bf0fdaa539e
rule HLP_integrityOfRepay(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    require receiver == e.msg.sender;
    
    uint256 assets;
    mathint balanceTokenBefore = token0.balanceOf(receiver);  
    mathint shareDebtTokenBefore = shareDebtToken0.balanceOf(receiver);  
       
    mathint shares = repay(e, assets, receiver);
    mathint balanceTokenAfter = token0.balanceOf(receiver);  
    mathint shareDebtTokenAfter = shareDebtToken0.balanceOf(receiver);  
   
    assert balanceTokenAfter == balanceTokenBefore - assets;
    satisfy balanceTokenAfter == balanceTokenBefore - assets;

    assert shareDebtTokenAfter == shareDebtTokenBefore - shares;
    satisfy shareDebtTokenAfter == shareDebtTokenBefore - shares;
}

