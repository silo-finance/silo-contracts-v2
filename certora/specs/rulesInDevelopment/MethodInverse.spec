import "../_common/CompleteSiloSetup.spec";
import "../_common/IsSiloFunction.spec";
import "../_common/SiloMethods.spec";
import "../_common/Helpers.spec";
import "../_common/CommonSummarizations.spec";
import "../_simplifications/Oracle_quote_one.spec";
//import "../_simplifications/priceOracle.spec";
import "../_simplifications/Silo_isSolvent_ghost.spec";
//import "../_simplifications/SiloSolvencyLib.spec";
import "../_simplifications/SimplifiedGetCompoundInterestRateAndUpdate.spec";

//holds
// https://prover.certora.com/output/6893/cb1d67e25666499aaa44bd4f62e39e66/?anonymousKey=0e33867f4b588f6baa00ccdfa821c9da5f63a049
rule HLP_depositAndInverse(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);
    sharesToAssetsFixedRatio(e);
    require e.block.timestamp == silo0.getSiloDataInterestRateTimestamp(e); //to avoid interest

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

    //satisfy balanceCollateralAfter <= balanceCollateralBefore;
    //satisfy balanceProtectedCollateralAfter == balanceProtectedCollateralBefore;
    //satisfy balanceTokenBefore == balanceTokenAfter;
}

rule HLP_mintAndInverse(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);
    sharesToAssetsFixedRatio(e);
    require e.block.timestamp == silo0.getSiloDataInterestRateTimestamp(e); //to avoid interest

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
    assert balanceTokenBefore >= balanceTokenAfter;

    satisfy balanceCollateralAfter == balanceCollateralBefore;
    satisfy balanceProtectedCollateralAfter == balanceProtectedCollateralBefore;
    satisfy balanceTokenBefore >= balanceTokenAfter;
}

rule HLP_borrowSharesAndInverse(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);
    sharesToAssetsFixedRatio(e);
    require e.block.timestamp == silo0.getSiloDataInterestRateTimestamp(e); //to avoid interest


    mathint debtBefore = shareDebtToken0.balanceOf(e.msg.sender);
    mathint balanceTokenBefore = token0.balanceOf(e.msg.sender);
    mathint balanceCollateralBefore = shareCollateralToken0.balanceOf(e.msg.sender);
    mathint balanceProtectedCollateralBefore = shareProtectedCollateralToken0.balanceOf(e.msg.sender);

    uint256 shares;
    bool sameAsset;
    
    mathint assetsB = borrowShares(e, shares, e.msg.sender, e.msg.sender, sameAsset);
    mathint assetsR = repayShares(e, shares, e.msg.sender);
    
    mathint debtAfter = shareDebtToken0.balanceOf(e.msg.sender);  
    mathint balanceTokenAfter = token0.balanceOf(e.msg.sender);
    mathint balanceCollateralAfter = shareCollateralToken0.balanceOf(e.msg.sender);
    mathint balanceProtectedCollateralAfter = shareProtectedCollateralToken0.balanceOf(e.msg.sender);
    
    assert debtBefore == debtAfter;
    assert balanceCollateralAfter == balanceCollateralBefore;
    assert balanceProtectedCollateralAfter == balanceProtectedCollateralBefore;
    assert balanceTokenBefore >= balanceTokenAfter;

    satisfy balanceCollateralAfter == balanceCollateralBefore;
    satisfy balanceProtectedCollateralAfter == balanceProtectedCollateralBefore;
    satisfy balanceTokenBefore >= balanceTokenAfter;
}

rule HLP_borrowAndInverse(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    sharesToAssetsFixedRatio(e);
    require e.block.timestamp == silo0.getSiloDataInterestRateTimestamp(e); //to avoid interest

    require shareCollateralToken0.totalSupply() == 10^6;
    
    uint256 assets;
    bool sameAsset;
    mathint debtBefore = shareDebtToken0.balanceOf(receiver);
    mathint sharesB = borrow(e, assets, receiver, receiver, sameAsset);
    mathint debtAfterB = shareDebtToken0.balanceOf(receiver);
    mathint sharesR = repay(e, assets, receiver);
    mathint debtAfterR = shareDebtToken0.balanceOf(receiver);
    
    mathint debtAfter = shareDebtToken0.balanceOf(receiver);  
    
    assert differsAtMost(debtAfter, debtBefore, 100);
    assert differsAtMost(debtAfter, debtBefore, 10);
    assert differsAtMost(debtAfter, debtBefore, 1);
    satisfy debtAfter == debtBefore;
}


// done and working
// done - timeout
// in progress - spurious CEXs, etc
// legacy, not maintained