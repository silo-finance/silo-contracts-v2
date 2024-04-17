import "../_common/CompleteSiloSetup.spec";
import "../_common/IsSiloFunction.spec";
import "../_common/SiloMethods.spec";
import "../_common/Helpers.spec";
import "../_common/CommonSummarizations.spec";
import "../_common/AccrueInterestWasCalled_hook.spec";
import "../../_simplifications/Oracle_quote_one.spec";
//import "../../_simplifications/Silo_isSolvent_ghost.spec";
import "../../_simplifications/SiloSolvencyLib.spec";
import "../../_simplifications/SimplifiedGetCompoundInterestRateAndUpdate.spec";

// These properties were already verified by the Silo team using rules in VariableChangesSilo0.spec
// Here we want to showcase a different approach to writing these: smaller a simpler rules rather than complex ones.
// Most of these are still in development (giving spurious CEXs)

// collateralShareToken.totalSupply and Silo._total[ISilo.AssetType.Collateral].assets 
//      should increase only on deposit, mint, and transitionCollateral. 
//      should decrease only on withdraw, redeem, liquidationCall.
// todo add other variants of the same method (redeem(..., uint8), ...)
// todo investigate underflow on withdraw
// https://prover.certora.com/output/6893/053f629b628648ad92079efe36bf1731/?anonymousKey=8d27b54436b2bb7aa3a99ddc1b3e175bd2373e25
rule whoCanChangeShareTokenTotalSupply(env e, method f) filtered { f -> !f.isView } 
{
    address receiver;
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(e.msg.sender);
    totalSupplyMoreThanBalance(receiver);

    mathint collateralTotalSupplyBefore = shareCollateralToken0.totalSupply();
    mathint totalColateralBefore;
    totalColateralBefore, _ = getCollateralAndProtectedAssets();
    
    calldataarg args;
    f(e, args);
    mathint collateralTotalSupplyAfter = shareCollateralToken0.totalSupply();
    mathint totalColateralAfter;
    totalColateralAfter, _ = getCollateralAndProtectedAssets();

    assert collateralTotalSupplyAfter > collateralTotalSupplyBefore => canIncreaseTotalCollateral(f);
    assert collateralTotalSupplyAfter < collateralTotalSupplyBefore => canDecreaseTotalCollateral(f);
}

// The balance of the silo in the underlying asset should in/decrease for the same amount 
// as Silo._total[ISilo.AssetType.Collateral].assets in/decreased.
// accrueInterest increase only Silo._total[ISilo.AssetType.Collateral].assets. 
rule totalCollateralToTokenBalanceCorrespondence(env e, method f) filtered { f -> !f.isView } 
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

// protectedShareToken.totalSupply and Silo._total[ISilo.AssetType.Protected].assets 
//      should increase only on deposit, mint, and transitionCollateral. 
//      should decrease only on withdraw, redeem, liquidationCall, and transitionCollateral. 
// todo investigate the underflow on withdraw
// https://prover.certora.com/output/6893/aacae5beb9b0469093dbc5fe045603ce/?anonymousKey=1b593216036053b602d60077813d921c069b2d2a
rule whoCanChangeProtectedShareTokenTotalSupply(env e, method f) filtered { f -> !f.isView } 
{
    address receiver;
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(e.msg.sender);
    totalSupplyMoreThanBalance(receiver);

    mathint protectedCollateralTotalSupplyBefore = shareProtectedCollateralToken0.totalSupply();
    mathint totalProtectedColateralBefore;
    _, totalProtectedColateralBefore = getCollateralAndProtectedAssets();
    
    calldataarg args;
    f(e, args);
    mathint protectedCollateralTotalSupplyAfter = shareProtectedCollateralToken0.totalSupply();
    mathint totalProtectedColateralAfter;
    _, totalProtectedColateralAfter = getCollateralAndProtectedAssets();

    assert protectedCollateralTotalSupplyAfter > protectedCollateralTotalSupplyBefore => canIncreaseTotalProtectedCollateral(f);
    assert protectedCollateralTotalSupplyAfter < protectedCollateralTotalSupplyBefore => canDecreaseTotalProtectedCollateral(f);
}

// The balance of the silo in the underlying asset should in/decrease for the same amount 
// as Silo._total[ISilo.AssetType.Protected].assets in/decreased.
// accrueInterest fn does not increase the protected assets.
rule totalProtectedCollateralToTokenBalanceCorrespondence(env e, method f) filtered { f -> !f.isView } 
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

// debtShareToken.totalSupply and Silo._total[ISilo.AssetType.Debt].assets 
//      should increase only on borrow, borrowShares, leverage. 
//      should decrease only on repay, repayShares, liquidationCall. 
// todo run hard parametric funcs separatelly
rule whoCanChangeDebtShareTokenTotalSupply(env e, method f) filtered { f -> !f.isView } 
{
    address receiver;
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(e.msg.sender);
    totalSupplyMoreThanBalance(receiver);

    mathint debtTotalSupplyBefore = shareDebtToken0.totalSupply();
    mathint totalDebtBefore;
    _, totalDebtBefore = getCollateralAndDebtAssets();
    
    calldataarg args;
    f(e, args);
    mathint debtTotalSupplyAfter = shareDebtToken0.totalSupply();
    mathint totalDebtAfter;
    _, totalDebtAfter = getCollateralAndDebtAssets();

    assert debtTotalSupplyAfter > debtTotalSupplyBefore => canIncreaseTotalDebt(f);
    assert debtTotalSupplyAfter < debtTotalSupplyBefore => canDecreaseTotalDebt(f);
}

// The balance of the silo in the underlying asset should de/increase for the same amount 
// as Silo._total[ISilo.AssetType.Debt].assets in/decreased. 
// accrueInterest increase only Silo._total[ISilo.AssetType.Debt].assets.
rule totalDebtToTokenBalanceCorrespondence(env e, method f) filtered { f -> !f.isView } 
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

// holds
// https://prover.certora.com/output/6893/98bcc5443c92413790ce3468c9a7e156/?anonymousKey=ca021fc532d4d0d9e459b52813c0bf026cda6b0a
rule whoCanChangeFees(env e, method f) filtered { f -> !f.isView } 
{
    completeSiloSetupEnv(e);
    uint256 accruedInterestBefore = currentContract.getSiloDataDaoAndDeployerFees();
    calldataarg args;
    f(e, args);
    uint256 accruedInterestAfter = currentContract.getSiloDataDaoAndDeployerFees();
    
    assert accruedInterestAfter > accruedInterestBefore => wasAccrueInterestCalled_silo0 || 
        f.selector == sig:flashLoan(address,address,uint256,bytes).selector;
    assert accruedInterestAfter < accruedInterestBefore => canDecreaseAccrueInterest(f);
}

//holds
// https://prover.certora.com/output/6893/e8150cd118cc418b9d0c9383166598e0/?anonymousKey=7a312573f7863bf0b0b938615376ef40669ac79c
rule whoCanChangeTimeStamp(env e, method f) filtered { f -> !f.isView } 
{
    completeSiloSetupEnv(e);
    uint256 timestampBefore = currentContract.getSiloDataInterestRateTimestamp();
    calldataarg args;
    f(e, args);
    uint256 timestampAfter = currentContract.getSiloDataInterestRateTimestamp();
    
    assert timestampAfter > timestampBefore => wasAccrueInterestCalled_silo0;
    assert timestampAfter < timestampBefore => canDecreaseTimestamp(f);
}

rule whoCanChangeBalanceShares(env e, method f) filtered { f -> !f.isView } 
{
    completeSiloSetupEnv(e);
    requireCollateralToken0TotalAndBalancesIntegrity();
    address receiver;

    mathint balanceSharesBefore = shareCollateralToken0.balanceOf(receiver);
    calldataarg args;
    f(e, args);
    mathint balanceSharesAfter = shareCollateralToken0.balanceOf(receiver);
    
    assert balanceSharesAfter > balanceSharesBefore => canIncreaseSharesBalance(f);
    assert balanceSharesAfter < balanceSharesBefore => canDecreaseSharesBalance(f);
}

rule whoCanChangeProtectedAssets(env e, method f) filtered { f -> !f.isView } 
{
    completeSiloSetupEnv(e);
    requireCollateralToken0TotalAndBalancesIntegrity();
    address receiver;

    mathint protectedAssetsBefore = silo0.total(ISilo.AssetType.Protected);
    calldataarg args;
    f(e, args);
    mathint protectedAssetsAfter = silo0.total(ISilo.AssetType.Protected);
    
    assert protectedAssetsAfter > protectedAssetsBefore => canIncreaseProtectedAssets(f);
    assert protectedAssetsAfter < protectedAssetsBefore => canDecreaseProtectedAssets(f);
}

rule protectedSharesBalance(env e, method f, address receiver) 
    filtered { f -> !f.isView} 
{
    completeSiloSetupEnv(e);
    requireProtectedToken0TotalAndBalancesIntegrity();

    mathint protectedtAssetsBefore = silo0.total(ISilo.AssetType.Protected);
    mathint balanceSharesBefore = shareProtectedCollateralToken0.balanceOf(receiver);

    calldataarg args;
    f(e, args);

    mathint protectedAssetsAfter = silo0.total(ISilo.AssetType.Protected);
    mathint balanceSharesAfter = shareProtectedCollateralToken0.balanceOf(receiver);

    assert balanceSharesBefore < balanceSharesAfter => protectedtAssetsBefore < protectedAssetsAfter,
        "The balance of share tokens should increase only if protected assets increased";

    assert balanceSharesBefore > balanceSharesAfter => protectedtAssetsBefore > protectedAssetsAfter,
        "The balance of share tokens should decrease only if protected assets decreased";
}
