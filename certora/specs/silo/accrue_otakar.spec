import "../requirements/CompleteSiloSetup.spec";
import "unresolved.spec";
import "../_simplifications/SiloMathLib.spec";
import "../_simplifications/Oracle_quote_one.spec";
import "../_simplifications/SimplifiedGetCompoundInterestRateAndUpdate.spec";

methods {

function SiloERC4626Lib.maxWithdrawWhenDebt(        
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address _owner,
        uint256 _liquidity,
        uint256 _shareTokenTotalSupply,
        ISilo.CollateralType _collateralType,
        uint256 _totalAssets) internal returns (uint256,uint256) => NONDET /* difficulty 83 */; 
function SiloLendingLib.calculateMaxBorrow( 
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address _borrower,
        uint256 _totalDebtAssets,
        uint256 _totalDebtShares,
        address _siloConfig) internal returns (uint256,uint256) => NONDET /* difficulty 118 */; 
function SiloSolvencyLib.getLtv(
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address _borrower,
        ISilo.OracleType _oracleType,
        ISilo.AccrueInterestInMemory _accrueInMemory,
        uint256 _debtShareBalance) internal returns (uint256) => NONDET /* difficulty 69 */; 
function SiloSolvencyLib.isSolvent(
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address _borrower,
        ISilo.AccrueInterestInMemory _accrueInMemory) internal returns (bool) => NONDET /* difficulty 53 */; 
function SiloLendingLib.maxBorrow(address,bool) internal returns (uint256,uint256) 
    => NONDET /* difficulty 186 */; 
function SiloERC4626Lib.maxWithdraw(address,ISilo.CollateralType,uint256) internal returns (uint256,uint256) 
    => NONDET /* difficulty 141 */; 
function SiloSolvencyLib.isBelowMaxLtv(
    ISiloConfig.ConfigData memory _collateralConfig,
    ISiloConfig.ConfigData memory _debtConfig,
    address _borrower,
    ISilo.AccrueInterestInMemory _accrueInMemory) internal returns (bool) => NONDET /* difficulty 53 */;
}

// accrueInterest doesn't affect sharesBalance
// state S -> call method f -> check balanceOf(user)
// state S -> call accrueInterest -> call method f -> check balanceOf(user)
rule accruing0DoesntAffectShareBalance(env e, address user, method f)
    filtered { f -> !filterOutInInvariants(f) }
{
    SafeAssumptions_withInvariants_forMethod(e, user, f);
    
    storage init = lastStorage;
    calldataarg args;
    f(e, args);
    mathint shares1 = silo0.balanceOf(user);

    silo0.accrueInterest(e) at init;
    f(e, args);
    mathint shares2 = silo0.balanceOf(user);

    assert shares1 == shares2;
}

// same as before, calls silo1.accrue in between
rule accruing1DoesntAffectShareBalance(env e, address user, method f)
    filtered { f -> !filterOutInInvariants(f) }
{
    SafeAssumptions_withInvariants_forMethod(e, user, f);
    
    storage init = lastStorage;
    calldataarg args;
    f(e, args);
    mathint shares1 = silo0.balanceOf(user);

    silo1.accrueInterest(e) at init;
    f(e, args);
    mathint shares2 = silo0.balanceOf(user);

    assert shares1 == shares2;
}

// same as before, checks assets instead
rule accruing0DoesntAffectAssetsBalance(env e, address user, method f)
    filtered { f -> !filterOutInInvariants(f) }
{
    SafeAssumptions_withInvariants_forMethod(e, user, f);
    
    storage init = lastStorage;
    calldataarg args;
    f(e, args);
    mathint assets1 = token0.balanceOf(user);

    silo0.accrueInterest(e) at init;
    f(e, args);
    mathint assets2 = token0.balanceOf(user);

    assert assets1 == assets2;
}

// same as before, calls silo1.accrue in between
rule accruing1DoesntAffectAssetsBalance(env e, address user, method f)
    filtered { f -> !filterOutInInvariants(f) }
{
    SafeAssumptions_withInvariants_forMethod(e, user, f);

    storage init = lastStorage;
    calldataarg args;
    f(e, args);
    mathint assets1 = token0.balanceOf(user);

    silo1.accrueInterest(e) at init;
    f(e, args);
    mathint assets2 = token0.balanceOf(user);

    assert assets1 == assets2;
}

// same as before, checks total assets instead
rule accruing0DoesntAffectTotalAssets(env e, address user, method f)
    filtered { f -> !filterOutInInvariants(f) }
{
    SafeAssumptions_withInvariants_forMethod(e, user, f);
    
    storage init = lastStorage;
    calldataarg args;
    f(e, args);
    mathint assets1 = token0.totalSupply();

    silo0.accrueInterest(e) at init;
    f(e, args);
    mathint assets2 = token0.totalSupply();

    assert assets1 == assets2;
}

// same as before, calls silo1.accrue in between
rule accruing1DoesntAffectTotalAssets(env e, address user, method f)
    filtered { f -> !filterOutInInvariants(f) }
{  
    SafeAssumptions_withInvariants_forMethod(e, user, f);
    
    storage init = lastStorage;
    calldataarg args;
    f(e, args);
    mathint assets1 = token0.totalSupply();

    silo1.accrueInterest(e) at init;
    f(e, args);
    mathint assets2 = token0.totalSupply();

    assert assets1 == assets2;
}