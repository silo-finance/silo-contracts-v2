import "./IsSiloFunction.spec";
import "./Helpers.spec";
import "./CommonSummarizations.spec";
import "./SiloConfigSummarizations.spec";
import "./ERC20MethodsDispatch.spec";
import "./Token0Methods.spec";
import "./Token1Methods.spec";
import "./Silo0ShareTokensMethods.spec";
import "./Silo1ShareTokensMethods.spec";

function completeSiloSetupEnv(env e) {
    
    completeSiloSetupAddress(e.msg.sender);
    // we can not have block.timestamp less than interestRateTimestamp
    require e.block.timestamp < (1 << 64);
    require e.block.timestamp >= silo0.getSiloDataInterestRateTimestamp(e);
    require e.block.timestamp >= silo1.getSiloDataInterestRateTimestamp(e);
}

function completeSiloSetupAddress(address sender)
{
    require sender != shareCollateralToken0;
    require sender != shareDebtToken0;
    require sender != shareProtectedCollateralToken0;
    require sender != shareProtectedCollateralToken1;
    require sender != shareDebtToken1;
    require sender != shareCollateralToken1;
    require sender != siloConfig;
    require sender != currentContract;  /// Silo0
    require sender != token0;
    require sender != token1;
    doesntHaveCollateralAsWellAsDebt(sender);
    
    //there are shares if and only if there are tokens
    //otherwise there are CEXs where borrow(a lot); repay(a little); removes all debt from the user, etc.
    require shareDebtToken0.totalSupply() == 0 <=> silo0.total(ISilo.AssetType.Debt) == 0;  
    require shareProtectedCollateralToken0.totalSupply() == 0 <=> silo0.total(ISilo.AssetType.Protected) == 0;
    require shareCollateralToken0.totalSupply() == 0 <=> silo0.total(ISilo.AssetType.Collateral) == 0;

    require shareDebtToken1.totalSupply() == 0 <=> silo1.total(ISilo.AssetType.Debt) == 0;
    require shareProtectedCollateralToken1.totalSupply() == 0 <=> silo1.total(ISilo.AssetType.Protected) == 0;
    require shareCollateralToken1.totalSupply() == 0 <=> silo1.total(ISilo.AssetType.Collateral) == 0;

}

function totalSupplyMoreThanBalance(address receiver)
{
    require receiver != currentContract;
    require token0.totalSupply() >= require_uint256(token0.balanceOf(receiver) + token0.balanceOf(currentContract));
    require shareProtectedCollateralToken0.totalSupply() >= require_uint256(shareProtectedCollateralToken0.balanceOf(receiver) + shareProtectedCollateralToken0.balanceOf(currentContract));
    require shareDebtToken0.totalSupply() >= require_uint256(shareDebtToken0.balanceOf(receiver) + shareDebtToken0.balanceOf(currentContract));
    require shareCollateralToken0.totalSupply() >= require_uint256(shareCollateralToken0.balanceOf(receiver) + shareCollateralToken0.balanceOf(currentContract));
    require token1.totalSupply() >= require_uint256(token1.balanceOf(receiver) + token1.balanceOf(currentContract));
    require shareProtectedCollateralToken1.totalSupply() >= require_uint256(shareProtectedCollateralToken1.balanceOf(receiver) + shareProtectedCollateralToken1.balanceOf(currentContract));
    require shareDebtToken1.totalSupply() >= require_uint256(shareDebtToken1.balanceOf(receiver) + shareDebtToken1.balanceOf(currentContract));
    require shareCollateralToken1.totalSupply() >= require_uint256(shareCollateralToken1.balanceOf(receiver) + shareCollateralToken1.balanceOf(currentContract));

    // otherwise there's an overflow in "unchecked" in SiloSolvencyLib.getPositionValues 
    require token0.totalSupply() >= require_uint256(
        silo0.total(ISilo.AssetType.Protected) + silo0.total(ISilo.AssetType.Collateral) + token0.balanceOf(receiver));
    require token1.totalSupply() >= require_uint256(
        silo1.total(ISilo.AssetType.Protected) + silo1.total(ISilo.AssetType.Collateral) + token1.balanceOf(receiver));

    // if user has debt he must have collateral in the other silo
    require shareDebtToken0.balanceOf(receiver) > 0 => (
        shareCollateralToken1.balanceOf(receiver) > 0 ||
        shareProtectedCollateralToken1.balanceOf(receiver) > 0);
    require shareDebtToken1.balanceOf(receiver) > 0 => (
        shareCollateralToken0.balanceOf(receiver) > 0 ||
        shareProtectedCollateralToken0.balanceOf(receiver) > 0);
}

function doesntHaveCollateralAsWellAsDebt(address user)
{
    require !(  //cannot have collateral AND debt on silo0
        (shareCollateralToken0.balanceOf(user) > 0 || 
        shareProtectedCollateralToken0.balanceOf(user) > 0) &&
        shareDebtToken0.balanceOf(user) > 0);
    
    require !(  //cannot have collateral AND debt on silo1
        (shareCollateralToken1.balanceOf(user) > 0 || 
        shareProtectedCollateralToken1.balanceOf(user) > 0) &&
        shareDebtToken1.balanceOf(user) > 0);
}

// initial state is treated differently. (When there's 0 collateral and debt shares)
function requireNotInitialState()
{
    require token0.totalSupply() > 0;
    require shareProtectedCollateralToken0.totalSupply() > 0;
    require shareDebtToken0.totalSupply() > 0;
    require shareCollateralToken0.totalSupply() > 0;
    require token1.totalSupply() > 0;
    require shareProtectedCollateralToken1.totalSupply() > 0;
    require shareDebtToken1.totalSupply() > 0;
    require shareCollateralToken1.totalSupply() > 0;
}

function requireTokensTotalAndBalanceIntegrity()
{
    requireProtectedToken0TotalAndBalancesIntegrity();
    requireDebtToken0TotalAndBalancesIntegrity();
    requireCollateralToken0TotalAndBalancesIntegrity();
    requireProtectedToken1TotalAndBalancesIntegrity();
    requireDebtToken1TotalAndBalancesIntegrity();
    requireCollateralToken1TotalAndBalancesIntegrity();
}

function sharesToAssetsNotTooHigh(env e, mathint max)
{
    mathint totalCollateralAssets; mathint totalProtectedAssets;
    totalCollateralAssets, totalProtectedAssets = getCollateralAndProtectedAssets(e);  
    mathint totalShares = shareCollateralToken0.totalSupply();
    mathint totalProtectedShares = shareProtectedCollateralToken0.totalSupply();
    require totalCollateralAssets <= totalShares * max;
    require totalShares <= totalCollateralAssets * max;
    require totalProtectedAssets <= totalProtectedShares * max;
    require totalProtectedShares <= totalProtectedAssets * max;
}

// limits token.totalSupply() and silo.total[] to reasonable values
function totalsNotTooHigh(env e, mathint max)
{
    mathint totalCollateralAssets0; mathint totalProtectedAssets0; mathint totalDebtAssets0;
    totalCollateralAssets0, totalProtectedAssets0 = silo0.getCollateralAndProtectedAssets(e);  
    _, totalDebtAssets0 = silo0.getCollateralAndDebtAssets();
    mathint totalCollateralShares0 = shareCollateralToken0.totalSupply();
    mathint totalProtectedShares0 = shareProtectedCollateralToken0.totalSupply();
    mathint totalDebtShares0 = shareDebtToken0.totalSupply();
    
    require totalCollateralAssets0 <= max;
    require totalProtectedAssets0 <= max;
    require totalDebtAssets0 <= max;
    require totalCollateralShares0 <= max;
    require totalProtectedShares0 <= max;
    require totalDebtShares0 <= max;

    mathint totalCollateralAssets1; mathint totalProtectedAssets1; mathint totalDebtAssets1;
    totalCollateralAssets1, totalProtectedAssets1 = silo1.getCollateralAndProtectedAssets(e);  
    _, totalDebtAssets1 = silo1.getCollateralAndDebtAssets();
    mathint totalCollateralShares1 = shareCollateralToken1.totalSupply();
    mathint totalProtectedShares1 = shareProtectedCollateralToken1.totalSupply();
    mathint totalDebtShares1 = shareDebtToken1.totalSupply();
    
    require totalCollateralAssets1 <= max;
    require totalProtectedAssets1 <= max;
    require totalDebtAssets1 <= max;
    require totalCollateralShares1 <= max;
    require totalProtectedShares1 <= max;
    require totalDebtShares1 <= max;
}

// three allowed ratios: 1:1, 3:5
function sharesToAssetsFixedRatio(env e)
{
    mathint totalCollateralAssets; mathint totalProtectedAssets;
    totalCollateralAssets, totalProtectedAssets = getCollateralAndProtectedAssets(e);  
    mathint totalShares = shareCollateralToken0.totalSupply();
    mathint totalProtectedShares = shareProtectedCollateralToken0.totalSupply();
    require totalCollateralAssets * 3 == totalShares * 5 ||
        //totalCollateralAssets * 5 == totalShares * 3 ||
        totalCollateralAssets == totalShares;
    
    require totalProtectedAssets * 3 == totalProtectedShares * 5 ||
        //totalProtectedAssets * 5 == totalProtectedShares * 3 ||
        totalProtectedAssets == totalProtectedShares;
}

function differsAtMost(mathint x, mathint y, mathint diff) returns bool
{
    if (x == y) return true;
    if (x < y) return y - x <= diff;
    return x - y <= diff;
}

definition canIncreaseAccrueInterest(method f) returns bool =
    f.selector == sig:accrueInterest().selector ||
    f.selector == sig:borrow(uint256,address,address).selector ||
    f.selector == sig:borrowShares(uint256,address,address).selector ||
    f.selector == sig:deposit(uint256,address).selector ||
    f.selector == sig:deposit(uint256,address,ISilo.AssetType).selector ||
    f.selector == sig:flashLoan(address,address,uint256,bytes).selector ||
    f.selector == sig:leverage(uint256,address,address,bytes).selector ||
    f.selector == sig:liquidationCall(address,address,address,uint256,bool).selector ||
    f.selector == sig:mint(uint256,address).selector ||
    f.selector == sig:mint(uint256,address,ISilo.AssetType).selector ||
    f.selector == sig:redeem(uint256,address,address).selector ||
    f.selector == sig:redeem(uint256,address,address,ISilo.AssetType).selector ||
    f.selector == sig:repay(uint256,address).selector ||
    f.selector == sig:repayShares(uint256,address).selector ||
    f.selector == sig:transitionCollateral(uint256,address,ISilo.AssetType).selector ||
    f.selector == sig:withdrawFees().selector ||
    f.selector == sig:withdraw(uint256,address,address).selector ||
    f.selector == sig:withdraw(uint256,address,address,ISilo.AssetType).selector;

definition canDecreaseAccrueInterest(method f) returns bool =
    f.selector == sig:accrueInterest().selector ||
    f.selector == sig:borrow(uint256,address,address).selector ||
    f.selector == sig:borrowShares(uint256,address,address).selector ||
    f.selector == sig:deposit(uint256,address).selector ||
    f.selector == sig:deposit(uint256,address,ISilo.AssetType).selector ||
    f.selector == sig:leverage(uint256,address,address,bytes).selector ||
    f.selector == sig:mint(uint256,address).selector ||
    f.selector == sig:mint(uint256,address,ISilo.AssetType).selector ||
    f.selector == sig:liquidationCall(address,address,address,uint256,bool).selector ||
    f.selector == sig:transitionCollateral(uint256,address,ISilo.AssetType).selector ||
    f.selector == sig:redeem(uint256,address,address).selector ||
    f.selector == sig:redeem(uint256,address,address,ISilo.AssetType).selector ||
    f.selector == sig:repay(uint256,address).selector ||
    f.selector == sig:repayShares(uint256,address).selector ||
    f.selector == sig:withdraw(uint256,address,address).selector ||
    f.selector == sig:withdrawFees().selector ||
    f.selector == sig:withdraw(uint256,address,address,ISilo.AssetType).selector;

definition canIncreaseTimestamp(method f) returns bool =
    f.selector == sig:accrueInterest().selector ||
    f.selector == sig:borrow(uint256,address,address).selector ||
    f.selector == sig:borrowShares(uint256,address,address).selector ||
    f.selector == sig:leverage(uint256,address,address,bytes).selector ||
    f.selector == sig:liquidationCall(address,address,address,uint256,bool).selector ||
    f.selector == sig:transitionCollateral(uint256,address,ISilo.AssetType).selector ||
    f.selector == sig:withdraw(uint256,address,address).selector ||
    f.selector == sig:withdraw(uint256,address,address,ISilo.AssetType).selector ||
    f.selector == sig:deposit(uint256,address).selector ||
    f.selector == sig:deposit(uint256,address,ISilo.AssetType).selector ||
    f.selector == sig:mint(uint256,address).selector ||
    f.selector == sig:mint(uint256,address,ISilo.AssetType).selector ||
    f.selector == sig:redeem(uint256,address,address).selector ||
    f.selector == sig:redeem(uint256,address,address,ISilo.AssetType).selector ||
    f.selector == sig:repay(uint256,address).selector ||
    f.selector == sig:repayShares(uint256,address).selector;

definition canDecreaseTimestamp(method f) returns bool =
    false;

definition canIncreaseSharesBalance(method f) returns bool =
    f.selector == sig:mint(uint256,address,ISilo.AssetType).selector ||
    f.selector == sig:mint(uint256,address).selector ||
    f.selector == sig:transfer(address,uint256).selector ||
    f.selector == sig:transferFrom(address,address,uint256).selector ||
    f.selector == sig:transitionCollateral(uint256,address,ISilo.AssetType).selector ||
    f.selector == sig:deposit(uint256,address,ISilo.AssetType).selector ||
    f.selector == sig:deposit(uint256,address).selector;

definition canDecreaseSharesBalance(method f) returns bool =
    f.selector == sig:redeem(uint256,address,address).selector ||
    f.selector == sig:redeem(uint256,address,address,ISilo.AssetType).selector ||
    f.selector == sig:transfer(address,uint256).selector ||
    f.selector == sig:transferFrom(address,address,uint256).selector ||
    f.selector == sig:transitionCollateral(uint256,address,ISilo.AssetType).selector ||
    f.selector == sig:withdraw(uint256,address,address).selector ||
    f.selector == sig:withdraw(uint256,address,address,ISilo.AssetType).selector ||
    f.selector == sig:withdrawCollateralsToLiquidator(uint256,uint256,address,address,bool).selector;
    
definition canIncreaseProtectedAssets(method f) returns bool =
    f.selector == sig:deposit(uint256,address,ISilo.AssetType).selector ||
    f.selector == sig:mint(uint256,address,ISilo.AssetType).selector ||
    f.selector == sig:transitionCollateral(uint256,address,ISilo.AssetType).selector;

definition canDecreaseProtectedAssets(method f) returns bool =
    f.selector == sig:redeem(uint256,address,address,ISilo.AssetType).selector ||
    f.selector == sig:withdraw(uint256,address,address,ISilo.AssetType).selector ||
    f.selector == sig:withdrawCollateralsToLiquidator(uint256,uint256,address,address,bool).selector ||
    f.selector == sig:transitionCollateral(uint256,address,ISilo.AssetType).selector;

definition canIncreaseTotalCollateral(method f) returns bool = 
    f.selector == sig:mint(uint256,address,ISilo.AssetType).selector ||
    f.selector == sig:mint(uint256,address).selector ||
    f.selector == sig:deposit(uint256,address,ISilo.AssetType).selector ||
    f.selector == sig:deposit(uint256,address).selector ||
    f.selector == sig:transitionCollateral(uint256,address,ISilo.AssetType).selector; 

definition canDecreaseTotalCollateral(method f) returns bool =
    f.selector == sig:redeem(uint256,address,address,ISilo.AssetType).selector ||
    f.selector == sig:withdraw(uint256,address,address,ISilo.AssetType).selector ||
    f.selector == sig:liquidationCall(address,address,address,uint256,bool).selector;

definition canIncreaseTotalProtectedCollateral(method f) returns bool = 
    canIncreaseTotalCollateral(f);

definition canDecreaseTotalProtectedCollateral(method f) returns bool =
    f.selector == sig:redeem(uint256,address,address,ISilo.AssetType).selector ||
    f.selector == sig:withdraw(uint256,address,address,ISilo.AssetType).selector ||
    f.selector == sig:liquidationCall(address,address,address,uint256,bool).selector ||
    f.selector == sig:transitionCollateral(uint256,address,ISilo.AssetType).selector;

definition canIncreaseTotalDebt(method f) returns bool =
    f.selector == sig:borrow(uint256,address,address).selector ||
    f.selector == sig:borrowShares(uint256,address,address).selector ||
    f.selector == sig:leverage(uint256,address,address,bytes).selector;

definition canDecreaseTotalDebt(method f) returns bool =
    f.selector == sig:liquidationCall(address,address,address,uint256,bool).selector ||    
    f.selector == sig:repay(uint256,address).selector ||
    f.selector == sig:repayShares(uint256,address).selector;