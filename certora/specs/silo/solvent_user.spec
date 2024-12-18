

/** 
@title Verify that for all function the solvency check is applied on any increases of debt or decrease of collateral 

*/
import "../setup/CompleteSiloSetup.spec";
import "../simplifications/SiloMathLib.spec";
import "../simplifications/Oracle_quote_one.spec";
import "../simplifications/SimplifiedGetCompoundInterestRateAndUpdate.spec";

import "./authorized_functions.spec";
import "./unresolved.spec";



methods {

     unresolved external in Silo0.callOnBehalfOfSilo(address,uint256,uint8,bytes) => DISPATCH(use_fallback=true) [
        
    ] default NONDET;

    function silo0.getTransferWithChecks() external  returns (bool) envfree;
    function silo1.getTransferWithChecks() external  returns (bool) envfree;
    function shareDebtToken0.getTransferWithChecks() external  returns (bool) envfree;
    function shareDebtToken1.getTransferWithChecks() external  returns (bool) envfree;
    function shareProtectedCollateralToken0.getTransferWithChecks() external  returns (bool) envfree;
    function shareProtectedCollateralToken1.getTransferWithChecks() external  returns (bool) envfree;
    function siloConfig.getDebtSilo(address) external returns (address) envfree;
    function _.isSolvent(address) external => DISPATCHER(true);

    
    
    // summary for the solvent check functions 
    function SiloSolvencyLib.isSolvent(
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address borrower,
        ISilo.AccrueInterestInMemory _accrueInMemory
    )  internal returns (bool) => updateSolvent(borrower);

    function SiloSolvencyLib.isBelowMaxLtv(
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address borrower,
        ISilo.AccrueInterestInMemory _accrueInMemory
    ) internal returns (bool) => updateSolvent(borrower);

}



ghost mapping(address => bool) solventCalled;

function updateSolvent(address user) returns bool {
    return solventCalled[user];
}

function allTransferWithChecks() returns bool
{
        return  silo0.getTransferWithChecks() &&
                silo1.getTransferWithChecks() &&
                shareDebtToken0.getTransferWithChecks() &&
                shareDebtToken1.getTransferWithChecks() && 
                shareProtectedCollateralToken0.getTransferWithChecks() && 
                shareProtectedCollateralToken1.getTransferWithChecks();
        
}

//@title The flag transferWithChecks is always on at then end of all public methods  
rule transferWithChecksAlwaysOn(method f)  filtered {f-> !onlySiloContractsMethods(f) && !f.isView}
{
    env e;
    calldataarg args;
    configForEightTokensSetupRequirements();
    nonSceneAddressRequirements(e.msg.sender);
    silosTimestampSetupRequirements(e);

    require allTransferWithChecks();
    f(e,args);
    assert allTransferWithChecks();
}



//@title Solvency check has been performed on the correct user 
rule solventChecked(method f)  filtered {f-> !onlySiloContractsMethods(f) && !f.isView}
{
    env e;
    address user; 
    SafeAssumptions_withInvariants(e, user);
    completeSiloSetupForEnv(e);
    require silo0.getSiloFromStorage(e) == silo0;
    require silo1.getSiloFromStorage(e) == silo1;

    accrueHasBeenCalled(e);

    require allTransferWithChecks(); 

    require silo0 == siloConfig.borrowerCollateralSilo[user];
    
    uint256 userCollateralBalancePre = silo0.balanceOf(e,user);
    uint256 userDebt0BalancePre = shareDebtToken0.balanceOf(user);
    uint256 userDebt1BalancePre = shareDebtToken1.balanceOf(user);
    
    if (f.selector == sig:Silo0.transferFrom(address,address,uint256).selector) {
        address from;
        address to;
        uint256 amount;
        totalSuppliesMoreThanThreeBalances(from,to,silo0);
        silo0.transferFrom(e,from,to,amount);
    }
    else {
        calldataarg args;
        f(e,args);
    }
    uint256 userCollateralBalancePost = silo0.balanceOf(e,user);
    uint256 userDebt0BalancePost = shareDebtToken0.balanceOf(user);
    uint256 userDebt1BalancePost = shareDebtToken1.balanceOf(user);
    

    assert  ( ( userCollateralBalancePre > userCollateralBalancePost && (userDebt0BalancePost!=0 || userDebt1BalancePost!=0)) || 
                userDebt0BalancePre < userDebt0BalancePost ||
                userDebt1BalancePre < userDebt1BalancePost ) =>

            solventCalled[user]; 
}
