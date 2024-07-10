import "../_common/CompleteSiloSetup.spec";
import "../_common/IsSiloFunction.spec";
import "../_common/SiloMethods.spec";
import "../_common/Helpers.spec";
import "../_common/CommonSummarizations.spec";
import "../_common/AccrueInterestWasCalled_hook.spec";
import "../_simplifications/Oracle_quote_one.spec";
//import "../_simplifications/Silo_isSolvent_ghost.spec";
import "../_simplifications/SiloMathLib.spec";
import "../_simplifications/SiloSolvencyLib.spec";
import "../_simplifications/SimplifiedGetCompoundInterestRateAndUpdate.spec";

// These properties were already verified by the Silo team using rules in VariableChangesSilo0.spec
// Here we want to showcase a different approach to writing these: smaller, simpler rules rather than complex ones.

//In development
// The balance of the silo in the underlying asset should in/decrease for the same amount 
// as Silo._total[ISilo.AssetType.Collateral].assets in/decreased.
// accrueInterest increase only Silo._total[ISilo.AssetType.Collateral].assets. 
rule totalCollateralToTokenBalanceCorrespondence(env e, method f) filtered { f -> !f.isView && !isIgnoredMethod(f) } 
{
    address receiver;
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(e.msg.sender);
    totalSupplyMoreThanBalance(receiver);
    require receiver != currentContract;

    mathint tokenBalanceBefore = token0.balanceOf(currentContract);
    mathint totalCollateralBefore;
    totalCollateralBefore, _ = getCollateralAndDebtAssets();
    
    siloFnSelectorWithReceiver(e, f, receiver);

    mathint tokenBalanceAfter = token0.balanceOf(currentContract);
    mathint totalCollateralAfter;
    totalCollateralAfter, _ = getCollateralAndDebtAssets();
    
    assert (totalCollateralAfter - totalCollateralBefore == tokenBalanceAfter - tokenBalanceBefore);
        //|| wasAccrueInterestCalled_silo0;
}

// In development
// The balance of the silo in the underlying asset should in/decrease for the same amount 
// as Silo._total[ISilo.AssetType.Protected].assets in/decreased.
// accrueInterest fn does not increase the protected assets.
rule totalProtectedCollateralToTokenBalanceCorrespondence(env e, method f) filtered { f -> !f.isView && !isIgnoredMethod(f) } 
{
    address receiver;
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(e.msg.sender);
    totalSupplyMoreThanBalance(receiver);
    require receiver != currentContract;

    mathint tokenBalanceBefore = token0.balanceOf(currentContract);
    mathint protectedCollateralBefore;
    _, protectedCollateralBefore = getCollateralAndProtectedAssets();
    
    siloFnSelectorWithReceiver(e, f, receiver);

    mathint tokenBalanceAfter = token0.balanceOf(currentContract);
    mathint protectedCollateralAfter;
    _, protectedCollateralAfter = getCollateralAndProtectedAssets();
    
    assert protectedCollateralAfter - protectedCollateralBefore == tokenBalanceAfter - tokenBalanceBefore;
}

// In development
// The balance of the silo in the underlying asset should de/increase for the same amount 
// as Silo._total[ISilo.AssetType.Debt].assets in/decreased. 
// accrueInterest increase only Silo._total[ISilo.AssetType.Debt].assets.
rule totalDebtToTokenBalanceCorrespondence(env e, method f) filtered { f -> !f.isView && !isIgnoredMethod(f) } 
{
    address receiver;
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(e.msg.sender);
    require receiver != currentContract;

    mathint tokenBalanceBefore = token0.balanceOf(currentContract);
    mathint totalDebtBefore;
    _, totalDebtBefore = getCollateralAndDebtAssets();
    
    siloFnSelectorWithReceiver(e, f, receiver);

    mathint tokenBalanceAfter = token0.balanceOf(currentContract);
    mathint totalDebtAfter;
    _, totalDebtAfter = getCollateralAndDebtAssets();
    
    assert totalDebtAfter - totalDebtBefore == tokenBalanceBefore - tokenBalanceAfter;
}

rule protectedSharesBalance(env e, method f, address receiver) 
    filtered { f -> !f.isView && !isIgnoredMethod(f)} 
{
    completeSiloSetupEnv(e);
    requireProtectedToken0TotalAndBalancesIntegrity();

    mathint protectedtAssetsBefore = silo0.total(require_uint256(ISilo.AssetType.Protected));
    mathint balanceSharesBefore = shareProtectedCollateralToken0.balanceOf(receiver);

    calldataarg args;
    f(e, args);

    mathint protectedAssetsAfter = silo0.total(require_uint256(ISilo.AssetType.Protected));
    mathint balanceSharesAfter = shareProtectedCollateralToken0.balanceOf(receiver);

    assert balanceSharesBefore < balanceSharesAfter => protectedtAssetsBefore < protectedAssetsAfter,
        "The balance of share tokens should increase only if protected assets increased";

    assert balanceSharesBefore > balanceSharesAfter => protectedtAssetsBefore > protectedAssetsAfter,
        "The balance of share tokens should decrease only if protected assets decreased";
}

