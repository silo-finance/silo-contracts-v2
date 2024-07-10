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

// collateralShareToken.totalSupply and Silo._total[ISilo.AssetType.Collateral].assets 
//      should increase only on deposit, mint, and transitionCollateral. 
//      should decrease only on withdraw, redeem, liquidationCall.
// TODO use siloFnSelector to correctly constrain balance of receiver, or run individual methods manually
// Otherwise there's an underflow in withdraw
rule whoCanChangeShareTokenTotalSupply(env e, method f) filtered 
    { f -> !f.isView && !isIgnoredMethod(f) } 
{
    address receiver;
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(e.msg.sender);
    totalSupplyMoreThanBalance(receiver);

    mathint collateralTotalSupplyBefore = shareCollateralToken0.totalSupply();
    mathint totalColateralBefore;
    totalColateralBefore, _ = getCollateralAndProtectedAssets();
    
    siloFnSelectorWithReceiver(e, f, receiver);
    //calldataarg args;
    //f(e, args);

    mathint collateralTotalSupplyAfter = shareCollateralToken0.totalSupply();
    mathint totalColateralAfter;
    totalColateralAfter, _ = getCollateralAndProtectedAssets();

    assert collateralTotalSupplyAfter > collateralTotalSupplyBefore => canIncreaseTotalCollateral(f);
    assert collateralTotalSupplyAfter < collateralTotalSupplyBefore => canDecreaseTotalCollateral(f);
}

// protectedShareToken.totalSupply and Silo._total[ISilo.AssetType.Protected].assets 
//      should increase only on deposit, mint, and transitionCollateral. 
//      should decrease only on withdraw, redeem, liquidationCall, and transitionCollateral. 
// TODO use siloFnSelector to correctly constrain balance of receiver, or run individual methods manually
// Otherwise there's an underflow in withdraw
rule whoCanChangeProtectedShareTokenTotalSupply(env e, method f) filtered 
    { f -> !f.isView && !isIgnoredMethod(f) } 
{
    address receiver;
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(e.msg.sender);
    totalSupplyMoreThanBalance(receiver);

    mathint protectedCollateralTotalSupplyBefore = shareProtectedCollateralToken0.totalSupply();
    mathint totalProtectedColateralBefore;
    _, totalProtectedColateralBefore = getCollateralAndProtectedAssets();
    
    siloFnSelectorWithReceiver(e, f, receiver);
    //calldataarg args;
    //f(e, args);

    mathint protectedCollateralTotalSupplyAfter = shareProtectedCollateralToken0.totalSupply();
    mathint totalProtectedColateralAfter;
    _, totalProtectedColateralAfter = getCollateralAndProtectedAssets();

    assert protectedCollateralTotalSupplyAfter > protectedCollateralTotalSupplyBefore => canIncreaseTotalProtectedCollateral(f);
    assert protectedCollateralTotalSupplyAfter < protectedCollateralTotalSupplyBefore => canDecreaseTotalProtectedCollateral(f);
}

// debtShareToken.totalSupply and Silo._total[ISilo.AssetType.Debt].assets 
//      should increase only on borrow, borrowShares, leverage. 
//      should decrease only on repay, repayShares, liquidationCall. 
// TODO use siloFnSelector to correctly constrain balance of receiver, or run individual methods manually
// Otherwise there's an underflow in withdraw
rule whoCanChangeDebtShareTokenTotalSupply(env e, method f) filtered 
{ f -> !f.isView && !isIgnoredMethod(f) } 
{
    address receiver;
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(e.msg.sender);
    totalSupplyMoreThanBalance(receiver);

    mathint debtTotalSupplyBefore = shareDebtToken0.totalSupply();
    mathint totalDebtBefore;
    _, totalDebtBefore = getCollateralAndDebtAssets();
    
    //calldataarg args;
    //f(e, args);
    siloFnSelectorWithReceiver(e, f, receiver);

    mathint debtTotalSupplyAfter = shareDebtToken0.totalSupply();
    mathint totalDebtAfter;
    _, totalDebtAfter = getCollateralAndDebtAssets();

    assert debtTotalSupplyAfter > debtTotalSupplyBefore => canIncreaseTotalDebt(f);
    assert debtTotalSupplyAfter < debtTotalSupplyBefore => canDecreaseTotalDebt(f);
}

// holds
rule whoCanChangeFees(env e, method f) filtered { f -> !f.isView && !isIgnoredMethod(f) } 
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

// holds
rule whoCanChangeTimeStamp(env e, method f) filtered { f -> !f.isView && !isIgnoredMethod(f) } 
{
    completeSiloSetupEnv(e);
    uint256 timestampBefore = currentContract.getSiloDataInterestRateTimestamp();
    calldataarg args;
    f(e, args);
    uint256 timestampAfter = currentContract.getSiloDataInterestRateTimestamp();
    
    assert timestampAfter > timestampBefore => wasAccrueInterestCalled_silo0;
    assert timestampAfter < timestampBefore => canDecreaseTimestamp(f);
}

// TODO use siloFnSelector to correctly constrain balance of receiver, or run individual methods manually
// Otherwise there's an underflow in withdraw
rule whoCanChangeBalanceShares(env e, method f) filtered { f -> !f.isView && !isIgnoredMethod(f) } 
{
    completeSiloSetupEnv(e);
    requireCollateralToken0TotalAndBalancesIntegrity();
    address receiver;
    require receiver != currentContract;

    mathint balanceSharesBefore = shareCollateralToken0.balanceOf(receiver);
    //calldataarg args;
    //f(e, args);
    siloFnSelectorWithReceiver(e, f, receiver);
    
    mathint balanceSharesAfter = shareCollateralToken0.balanceOf(receiver);
    
    assert balanceSharesAfter > balanceSharesBefore => canIncreaseSharesBalance(f);
    assert balanceSharesAfter < balanceSharesBefore => canDecreaseSharesBalance(f);
}

// TODO use siloFnSelector to correctly constrain balance of receiver, or run individual methods manually
// Otherwise there's an underflow in withdraw
rule whoCanChangeProtectedAssets(env e, method f) filtered 
    { f -> !f.isView && !isIgnoredMethod(f) } 
{
    completeSiloSetupEnv(e);
    requireCollateralToken0TotalAndBalancesIntegrity();
    address receiver;

    mathint protectedAssetsBefore = silo0.total(require_uint256(ISilo.AssetType.Protected));
    //calldataarg args;
    //f(e, args);
    siloFnSelectorWithReceiver(e, f, receiver);
    
    mathint protectedAssetsAfter = silo0.total(require_uint256(ISilo.AssetType.Protected));
    
    assert protectedAssetsAfter > protectedAssetsBefore => canIncreaseProtectedAssets(f);
    assert protectedAssetsAfter < protectedAssetsBefore => canDecreaseProtectedAssets(f);
}
