import "../_common/CompleteSiloSetup.spec";
import "../_common/IsSiloFunction.spec";
import "../_common/SiloMethods.spec";
import "../_common/Helpers.spec";
import "../_common/CommonSummarizations.spec";
import "../../_simplifications/Oracle_quote_one.spec";
import "../../_simplifications/Silo_isSolvent_ghost.spec";
import "../../_simplifications/SimplifiedGetCompoundInterestRateAndUpdate.spec";

rule HLP_depositAndInverse(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);
    
    uint256 assets;
    
    mathint balanceTokenBefore = token0.balanceOf(e.msg.sender);
    mathint balanceCollateralBefore = shareCollateralToken0.balanceOf(receiver);
    mathint balanceProtectedCollateralBefore = shareProtectedCollateralToken0.balanceOf(receiver);

    mathint sharesD = deposit(e, assets, receiver);
    mathint sharesW = withdraw(e, assets, e.msg.sender, receiver);
    
    mathint balanceTokenAfter = token0.balanceOf(e.msg.sender);
    mathint balanceCollateralAfter = shareCollateralToken0.balanceOf(receiver);
    mathint balanceProtectedCollateralAfter = shareProtectedCollateralToken0.balanceOf(receiver);
    
    assert balanceCollateralAfter <= balanceCollateralBefore;
    assert balanceProtectedCollateralAfter == balanceProtectedCollateralBefore;
    assert balanceTokenBefore == balanceTokenAfter;

    satisfy balanceCollateralAfter <= balanceCollateralBefore;
    satisfy balanceProtectedCollateralAfter == balanceProtectedCollateralBefore;
    satisfy balanceTokenBefore == balanceTokenAfter;
}

rule HLP_mintAndInverse(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);
    
    mathint balanceTokenBefore = token0.balanceOf(e.msg.sender);
    mathint balanceCollateralBefore = shareCollateralToken0.balanceOf(receiver);
    mathint balanceProtectedCollateralBefore = shareProtectedCollateralToken0.balanceOf(receiver);

    uint256 shares;
    mathint assetsM = mint(e, shares, receiver);
    mathint assetsR = redeem(e, shares, e.msg.sender, receiver);
    
    mathint balanceTokenAfter = token0.balanceOf(e.msg.sender);
    mathint balanceCollateralAfter = shareCollateralToken0.balanceOf(receiver);
    mathint balanceProtectedCollateralAfter = shareProtectedCollateralToken0.balanceOf(receiver);
    
    assert balanceCollateralAfter == balanceCollateralBefore;
    assert balanceProtectedCollateralAfter == balanceProtectedCollateralBefore;
    assert balanceTokenBefore <= balanceTokenAfter;

    satisfy balanceCollateralAfter == balanceCollateralBefore;
    satisfy balanceProtectedCollateralAfter == balanceProtectedCollateralBefore;
    satisfy balanceTokenBefore <= balanceTokenAfter;
}

rule HLP_borrowSharesAndInverse(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);
    
    mathint debtBefore = shareDebtToken0.balanceOf(e.msg.sender);
    mathint balanceTokenBefore = token0.balanceOf(e.msg.sender);
    mathint balanceCollateralBefore = shareCollateralToken0.balanceOf(e.msg.sender);
    mathint balanceProtectedCollateralBefore = shareProtectedCollateralToken0.balanceOf(e.msg.sender);

    uint256 shares;
    
    mathint assetsB = borrowShares(e, shares, e.msg.sender, e.msg.sender);
    mathint assetsR = repayShares(e, shares, e.msg.sender);
    
    mathint debtAfter = shareDebtToken0.balanceOf(e.msg.sender);  
    mathint balanceTokenAfter = token0.balanceOf(e.msg.sender);
    mathint balanceCollateralAfter = shareCollateralToken0.balanceOf(e.msg.sender);
    mathint balanceProtectedCollateralAfter = shareProtectedCollateralToken0.balanceOf(e.msg.sender);
    
    assert debtBefore == debtAfter;
    assert balanceCollateralAfter == balanceCollateralBefore;
    assert balanceProtectedCollateralAfter == balanceProtectedCollateralBefore;
    assert balanceTokenBefore <= balanceTokenAfter;

    satisfy balanceCollateralAfter == balanceCollateralBefore;
    satisfy balanceProtectedCollateralAfter == balanceProtectedCollateralBefore;
    satisfy balanceTokenBefore <= balanceTokenAfter;
}

