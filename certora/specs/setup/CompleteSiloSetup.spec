import "two_silos_tokens_requirements.spec";
import "summaries/two_silos_summaries.spec";
import "summaries/siloconfig_dispatchers.spec";
import "summaries/config_for_two_in_cvl.spec";
import "summaries/safe-approximations.spec";

function SafeAssumptionsEnv_simple(env e) 
{
    completeSiloSetupForEnv(e);
}

function SafeAssumptionsEnv_withInvariants(env e) 
{
    SafeAssumptionsEnv_simple(e);
    requireEnvFreeInvariants();
    requireEnvInvariants(e);
}

function SafeAssumptions_withInvariants(env e, address user) 
{
    require user != 0;  //TODO not safe!!
    SafeAssumptionsEnv_withInvariants(e);
    requireEnvAndUserInvariants(e, user);
}

function SafeAssumptions_withInvariants_forMethod(env e, address user, method f) 
{
    // otherwise we get vacuity 
    if (!siloOnlyCallable(f)) nonSceneAddressRequirements(e.msg.sender);
    require user != 0;  //TODO not safe!!
    requireEnvFreeInvariants();
    requireEnvInvariants(e);
    requireEnvAndUserInvariants(e, user);
    configForEightTokensSetupRequirements();
    silosTimestampSetupRequirements(e);
}

function completeSiloSetupForEnv(env e) 
{
    configForEightTokensSetupRequirements();
    nonSceneAddressRequirements(e.msg.sender);
    silosTimestampSetupRequirements(e);
}

//////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////
/////  basic invariants
////////////////////////////

//there are shares if and only if there are tokens
// otherwise there are CEXs where borrow(a lot); repay(a little); removes all debt from the user, etc.
invariant shareDebtToken0_tracked()         shareDebtToken0.totalSupply() == 0 <=> silo0.getTotalAssetsStorage(ISilo.AssetType.Debt) == 0;
invariant shareProtectedToken0_tracked()    shareProtectedCollateralToken0.totalSupply() == 0 <=> silo0.getTotalAssetsStorage(ISilo.AssetType.Protected) == 0;
invariant siloToken0_tracked()              silo0.totalSupply() == 0 <=> silo0.getTotalAssetsStorage(ISilo.AssetType.Collateral) == 0;
invariant shareDebtToken1_tracked()         shareDebtToken1.totalSupply() == 0 <=> silo1.getTotalAssetsStorage(ISilo.AssetType.Debt) == 0;
invariant shareProtectedToken1_tracked()    shareProtectedCollateralToken1.totalSupply() == 0 <=> silo1.getTotalAssetsStorage(ISilo.AssetType.Protected) == 0;
invariant siloToken1_tracked()              silo1.totalSupply() == 0 <=> silo1.getTotalAssetsStorage(ISilo.AssetType.Collateral) == 0;


// sum of [(normal)assets + protected assets + balance of any user] is no more than totalSupply of the token
// otherwise there's an overflow in "unchecked" in SiloSolvencyLib.getPositionValues 
invariant token0Distribution(address user)
    token0.totalSupply() >= require_uint256(
        silo0.getTotalAssetsStorage(ISilo.AssetType.Protected) + 
        silo0.getTotalAssetsStorage(ISilo.AssetType.Collateral) + 
        token0.balanceOf(user));

invariant token1Distribution(address user) 
    token1.totalSupply() >= require_uint256(
        silo1.getTotalAssetsStorage(ISilo.AssetType.Protected) + 
        silo1.getTotalAssetsStorage(ISilo.AssetType.Collateral) + 
        token1.balanceOf(user));

// if user has debt then they must have collateral
invariant debt0ThenHasCollateral(address user)
    shareDebtToken0.balanceOf(user) > 0 => (silo1.balanceOf(user) > 0 || shareProtectedCollateralToken1.balanceOf(user) > 0);

invariant debt1ThenHasCollateral(address user) 
    shareDebtToken1.balanceOf(user) > 0 => (silo0.balanceOf(user) > 0 || shareProtectedCollateralToken0.balanceOf(user) > 0);

// no more shares than assets
invariant noMoreSharesThanAssets_0() silo0.totalSupply() <= silo0.getTotalAssetsStorage(ISilo.AssetType.Collateral);
invariant noMoreSharesThanAssets_1() silo1.totalSupply() <= silo1.getTotalAssetsStorage(ISilo.AssetType.Collateral);

//////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////
/////  functions for requiring the invariants
////////////////////////////

function requireAllInvariants(env e, address user)
{
    requireEnvFreeInvariants();
    requireEnvInvariants(e);
    requireEnvAndUserInvariants(e, user);
}

// requires all the non-parametric invariants defined bellow.
// !!  if you add more, also require them here    !!
function requireEnvFreeInvariants()
{
    requireInvariant shareDebtToken0_tracked();
    requireInvariant shareProtectedToken0_tracked();    
    requireInvariant siloToken0_tracked();              
    requireInvariant shareDebtToken1_tracked();
    requireInvariant shareProtectedToken1_tracked();
    requireInvariant siloToken1_tracked();
    requireInvariant noMoreSharesThanAssets_0();
    requireInvariant noMoreSharesThanAssets_1();
}

// requires all the invariants with env defined bellow.
// !!  if you add more, also require them here    !!
function requireEnvInvariants(env e)
{
    totalSuppliesMoreThanBalances(e.msg.sender, silo0);
    requireInvariant token0Distribution(e.msg.sender);
    requireInvariant token1Distribution(e.msg.sender);
    //requireInvariant debt0ThenHasCollateral(e.msg.sender);
    //requireInvariant debt1ThenHasCollateral(e.msg.sender);
}

// requires all the invariants with env and user defined bellow.
// !!  if you add more, also require them here    !!
function requireEnvAndUserInvariants(env e, address user)
{
    totalSuppliesMoreThanThreeBalances(e.msg.sender, user, silo0);

    requireInvariant token0Distribution(e.msg.sender);
    requireInvariant token1Distribution(e.msg.sender);
    //requireInvariant debt0ThenHasCollateral(e.msg.sender);
    //requireInvariant debt1ThenHasCollateral(e.msg.sender);
}

//////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////
/// unsafe assumptions. use with caution
////////////////////////////

// initial state is treated differently. (When there's 0 collateral and debt shares)
function requireNotInitialState()
{
    require token0.totalSupply() > 0;
    require shareProtectedCollateralToken0.totalSupply() > 0;
    require shareDebtToken0.totalSupply() > 0;
    require silo0.totalSupply() > 0;
    require token1.totalSupply() > 0;
    require shareProtectedCollateralToken1.totalSupply() > 0;
    require shareDebtToken1.totalSupply() > 0;
    require silo1.totalSupply() > 0;
}

// limits the [assets / shares] to reasonable values
function sharesToAssetsNotTooHigh(env e, mathint max)
{
    mathint totalCollateralAssets; mathint totalProtectedAssets;
    totalCollateralAssets, totalProtectedAssets = silo0.getCollateralAndProtectedTotalsStorage(e);  
    mathint totalShares = silo0.totalSupply();
    mathint totalProtectedShares = shareProtectedCollateralToken0.totalSupply();
    require totalCollateralAssets <= totalShares * max;
    require totalShares <= totalCollateralAssets * max;
    require totalProtectedAssets <= totalProtectedShares * max;
    require totalProtectedShares <= totalProtectedAssets * max;
}

//////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////
/////  definitions, methods' privileges 
////////////////////////////

definition canIncreaseAccrueInterest(method f) returns bool =
    f.selector == sig:Silo0.accrueInterest().selector ||
    f.selector == sig:Silo0.borrow(uint256,address,address).selector ||
    f.selector == sig:Silo0.borrowShares(uint256,address,address).selector ||
    f.selector == sig:Silo0.deposit(uint256,address).selector ||
    f.selector == sig:Silo0.deposit(uint256,address,ISilo.CollateralType).selector ||
    f.selector == sig:Silo0.flashLoan(address,address,uint256,bytes).selector ||
    f.selector == sig:Silo0.mint(uint256,address).selector ||
    f.selector == sig:Silo0.mint(uint256,address,ISilo.CollateralType).selector ||
    f.selector == sig:Silo0.redeem(uint256,address,address).selector ||
    f.selector == sig:Silo0.redeem(uint256,address,address,ISilo.CollateralType).selector ||
    f.selector == sig:Silo0.repay(uint256,address).selector ||
    f.selector == sig:Silo0.repayShares(uint256,address).selector ||
    f.selector == sig:Silo0.transitionCollateral(uint256,address,ISilo.CollateralType).selector ||
    f.selector == sig:Silo0.withdrawFees().selector ||
    f.selector == sig:Silo0.withdraw(uint256,address,address).selector ||
    f.selector == sig:Silo0.withdraw(uint256,address,address,ISilo.CollateralType).selector;

definition canDecreaseAccrueInterest(method f) returns bool =
    f.selector == sig:Silo0.accrueInterest().selector ||
    f.selector == sig:Silo0.borrow(uint256,address,address).selector ||
    f.selector == sig:Silo0.borrowShares(uint256,address,address).selector ||
    f.selector == sig:Silo0.deposit(uint256,address).selector ||
    f.selector == sig:Silo0.deposit(uint256,address,ISilo.CollateralType).selector ||
    f.selector == sig:Silo0.mint(uint256,address).selector ||
    f.selector == sig:Silo0.mint(uint256,address,ISilo.CollateralType).selector ||
    f.selector == sig:Silo0.transitionCollateral(uint256,address,ISilo.CollateralType).selector ||
    f.selector == sig:Silo0.redeem(uint256,address,address).selector ||
    f.selector == sig:Silo0.redeem(uint256,address,address,ISilo.CollateralType).selector ||
    f.selector == sig:Silo0.repay(uint256,address).selector ||
    f.selector == sig:Silo0.repayShares(uint256,address).selector ||
    f.selector == sig:Silo0.withdraw(uint256,address,address).selector ||
    f.selector == sig:Silo0.withdrawFees().selector ||
    f.selector == sig:Silo0.withdraw(uint256,address,address,ISilo.CollateralType).selector;

definition canIncreaseTimestamp(method f) returns bool =
    f.selector == sig:Silo0.accrueInterest().selector ||
    f.selector == sig:Silo0.borrow(uint256,address,address).selector ||
    f.selector == sig:Silo0.borrowShares(uint256,address,address).selector ||
    f.selector == sig:Silo0.transitionCollateral(uint256,address,ISilo.CollateralType).selector ||
    f.selector == sig:Silo0.withdraw(uint256,address,address).selector ||
    f.selector == sig:Silo0.withdraw(uint256,address,address,ISilo.CollateralType).selector ||
    f.selector == sig:Silo0.deposit(uint256,address).selector ||
    f.selector == sig:Silo0.deposit(uint256,address,ISilo.CollateralType).selector ||
    f.selector == sig:Silo0.mint(uint256,address).selector ||
    f.selector == sig:Silo0.mint(uint256,address,ISilo.CollateralType).selector ||
    f.selector == sig:Silo0.redeem(uint256,address,address).selector ||
    f.selector == sig:Silo0.redeem(uint256,address,address,ISilo.CollateralType).selector ||
    f.selector == sig:Silo0.repay(uint256,address).selector ||
    f.selector == sig:Silo0.repayShares(uint256,address).selector;

definition canDecreaseTimestamp(method f) returns bool =
    false;

definition canIncreaseSharesBalance(method f) returns bool =
    f.selector == sig:Silo0.mint(uint256,address,ISilo.CollateralType).selector ||
    f.selector == sig:Silo0.mint(uint256,address).selector ||
    f.selector == sig:Silo0.transfer(address,uint256).selector ||
    f.selector == sig:Silo0.transferFrom(address,address,uint256).selector ||
    f.selector == sig:Silo0.transitionCollateral(uint256,address,ISilo.CollateralType).selector ||
    f.selector == sig:Silo0.deposit(uint256,address,ISilo.CollateralType).selector ||
    f.selector == sig:Silo0.deposit(uint256,address).selector;

definition canDecreaseSharesBalance(method f) returns bool =
    f.selector == sig:Silo0.redeem(uint256,address,address).selector ||
    f.selector == sig:Silo0.redeem(uint256,address,address,ISilo.CollateralType).selector ||
    f.selector == sig:Silo0.transfer(address,uint256).selector ||
    f.selector == sig:Silo0.transferFrom(address,address,uint256).selector ||
    f.selector == sig:Silo0.transitionCollateral(uint256,address,ISilo.CollateralType).selector ||
    f.selector == sig:Silo0.withdraw(uint256,address,address).selector ||
    f.selector == sig:Silo0.withdraw(uint256,address,address,ISilo.CollateralType).selector;
    
definition canIncreaseProtectedAssets(method f) returns bool =
    f.selector == sig:Silo0.deposit(uint256,address,ISilo.CollateralType).selector ||
    f.selector == sig:Silo0.mint(uint256,address,ISilo.CollateralType).selector ||
    f.selector == sig:Silo0.transitionCollateral(uint256,address,ISilo.CollateralType).selector;

definition canDecreaseProtectedAssets(method f) returns bool =
    f.selector == sig:Silo0.redeem(uint256,address,address,ISilo.CollateralType).selector ||
    f.selector == sig:Silo0.withdraw(uint256,address,address,ISilo.CollateralType).selector ||
    f.selector == sig:Silo0.transitionCollateral(uint256,address,ISilo.CollateralType).selector;

definition canIncreaseTotalCollateral(method f) returns bool = 
    f.selector == sig:Silo0.mint(uint256,address,ISilo.CollateralType).selector ||
    f.selector == sig:Silo0.mint(uint256,address).selector ||
    f.selector == sig:Silo0.deposit(uint256,address,ISilo.CollateralType).selector ||
    f.selector == sig:Silo0.deposit(uint256,address).selector ||
    f.selector == sig:Silo0.transitionCollateral(uint256,address,ISilo.CollateralType).selector; 

definition canDecreaseTotalCollateral(method f) returns bool =
    f.selector == sig:Silo0.redeem(uint256,address,address,ISilo.CollateralType).selector ||
    f.selector == sig:Silo0.withdraw(uint256,address,address,ISilo.CollateralType).selector;
    
definition canIncreaseTotalProtectedCollateral(method f) returns bool = 
    canIncreaseTotalCollateral(f);

definition canDecreaseTotalProtectedCollateral(method f) returns bool =
    f.selector == sig:Silo0.redeem(uint256,address,address,ISilo.CollateralType).selector ||
    f.selector == sig:Silo0.withdraw(uint256,address,address,ISilo.CollateralType).selector;
    
definition canIncreaseTotalDebt(method f) returns bool =
    f.selector == sig:Silo0.borrow(uint256,address,address).selector ||
    f.selector == sig:Silo0.borrowShares(uint256,address,address).selector;
    
definition canDecreaseTotalDebt(method f) returns bool =
    f.selector == sig:Silo0.repay(uint256,address).selector ||
    f.selector == sig:Silo0.repayShares(uint256,address).selector;

definition canIncreaseDebt(method f) returns bool =
    f.selector == sig:Silo0.borrow(uint256,address,address).selector ||
    f.selector == sig:Silo0.borrowShares(uint256,address,address).selector;

definition canDecreaseDebt(method f) returns bool =
    f.selector == sig:Silo0.repay(uint256,address).selector ||
    f.selector == sig:Silo0.repayShares(uint256,address).selector;

definition harnessFunction(method f) returns bool =
    false;

definition siloOnlyCallable(method f) returns bool =
    f.selector == sig:Silo0.initialize(address).selector ||
    f.selector == sig:Silo1.initialize(address).selector ||
    f.selector == sig:Silo0.burn(address,address,uint256).selector ||
    f.selector == sig:Silo1.burn(address,address,uint256).selector ||
    f.selector == sig:Silo0.forwardTransferFromNoChecks(address,address,uint256).selector ||
    f.selector == sig:Silo1.forwardTransferFromNoChecks(address,address,uint256).selector ||
    f.selector == sig:Silo0.mint(address,address,uint256).selector ||
    f.selector == sig:Silo1.mint(address,address,uint256).selector;

definition ignoredFunction(method f) returns bool =
    harnessFunction(f) ||
    f.selector == sig:Silo0.callOnBehalfOfSilo(address, uint256, ISilo.CallType, bytes).selector ||
    f.selector == sig:Silo1.callOnBehalfOfSilo(address, uint256, ISilo.CallType, bytes).selector;


definition filterOutInInvariants(method f) returns bool =
    f.isView ||
    ignoredFunction(f);

//////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////
/// ideas, left over pices of code
//////////////////////////////

// prove that (accrueInterest; f();) has the same effect as f()
// afterwards add require that accrueInterest was already called before.
// It will simplify some methods, save runtime

// getExactLiquidationAmount can be simplified
// just assume that the resulting LTV is above the liquidation treshold (solvent LTV)

// SiloStdLib.getTotalCollateralAssetsWithInterest should return 
// the same value for a given total collateral and block. !!!

function differsAtMost(mathint x, mathint y, mathint diff) returns bool
{
    if (x == y) return true;
    if (x < y) return y - x <= diff;
    return x - y <= diff;
}

function max(mathint a, mathint b) returns mathint
{
    if (a < b) return b;
    return a;
}

// // limits token.totalSupply() and silo.total[] to reasonable values
// function totalsNotTooHigh(env e, mathint max)
// {
//     mathint totalCollateralAssets0; mathint totalProtectedAssets0; mathint totalDebtAssets0;
//     totalCollateralAssets0, totalProtectedAssets0 = silo0.getCollateralAndProtectedTotalsStorage(e);  
//     _, totalDebtAssets0 = silo0.getCollateralAndDebtAssets();
//     mathint totalCollateralShares0 = silo0.totalSupply();
//     mathint totalProtectedShares0 = shareProtectedCollateralToken0.totalSupply();
//     mathint totalDebtShares0 = shareDebtToken0.totalSupply();
    
//     require totalCollateralAssets0 <= max;
//     require totalProtectedAssets0 <= max;
//     require totalDebtAssets0 <= max;
//     require totalCollateralShares0 <= max;
//     require totalProtectedShares0 <= max;
//     require totalDebtShares0 <= max;

//     mathint totalCollateralAssets1; mathint totalProtectedAssets1; mathint totalDebtAssets1;
//     totalCollateralAssets1, totalProtectedAssets1 = silo1.getCollateralAndProtectedTotalsStorage(e);  
//     _, totalDebtAssets1 = silo1.getCollateralAndDebtAssets();
//     mathint totalCollateralShares1 = silo1.totalSupply();
//     mathint totalProtectedShares1 = shareProtectedCollateralToken1.totalSupply();
//     mathint totalDebtShares1 = shareDebtToken1.totalSupply();
    
//     require totalCollateralAssets1 <= max;
//     require totalProtectedAssets1 <= max;
//     require totalDebtAssets1 <= max;
//     require totalCollateralShares1 <= max;
//     require totalProtectedShares1 <= max;
//     require totalDebtShares1 <= max;
// }

// // two allowed ratios: 1:1, 3:5
// function sharesToAssetsFixedRatio(env e)
// {
//     mathint totalCollateralAssets; mathint totalProtectedAssets;
//     totalCollateralAssets, totalProtectedAssets = getCollateralAndProtectedTotalsStorage(e);  
//     mathint totalShares = silo0.totalSupply();
//     mathint totalProtectedShares = shareProtectedCollateralToken0.totalSupply();
//     require totalCollateralAssets * 3 == totalShares * 5 ||
//         //totalCollateralAssets * 5 == totalShares * 3 ||
//         totalCollateralAssets == totalShares;
    
//     require totalProtectedAssets * 3 == totalProtectedShares * 5 ||
//         //totalProtectedAssets * 5 == totalProtectedShares * 3 ||
//         totalProtectedAssets == totalProtectedShares;
// }

// old invariants

// // total supply is more than balance - 1 user
// invariant totalSupplyMoreThanBalance_token0(address user)               token0.totalSupply() >= token0.balanceOf(user);
// invariant totalSupplyMoreThanBalance_shareProtectedToken0(address user) shareProtectedCollateralToken0.totalSupply() >= shareProtectedCollateralToken0.balanceOf(user);
// invariant totalSupplyMoreThanBalance_shareDebtToken0(address user)      shareDebtToken0.totalSupply() >= shareDebtToken0.balanceOf(user);
// invariant totalSupplyMoreThanBalance_siloToken0(address user)           silo0.totalSupply() >= silo0.balanceOf(user);
// invariant totalSupplyMoreThanBalance_token1(address user)               token1.totalSupply() >= token1.balanceOf(user);
// invariant totalSupplyMoreThanBalance_shareProtectedToken1(address user) shareProtectedCollateralToken1.totalSupply() >= shareProtectedCollateralToken1.balanceOf(user);
// invariant totalSupplyMoreThanBalance_shareDebtToken1(address user)      shareDebtToken1.totalSupply() >= shareDebtToken1.balanceOf(user);
// invariant totalSupplyMoreThanBalance_siloToken1(address user)           silo1.totalSupply() >= silo1.balanceOf(user);

// // total supply is more than balance - 2 users
// invariant totalSupplyMoreThanBalance2_token0(address user0, address user1)
//     user0 != user1 => token0.totalSupply() >= require_uint256(token0.balanceOf(user0) + token0.balanceOf(user1));
// invariant totalSupplyMoreThanBalance2_shareProtectedToken0(address user0, address user1)
//     user0 != user1 => shareProtectedCollateralToken0.totalSupply() >= require_uint256(shareProtectedCollateralToken0.balanceOf(user0) + shareProtectedCollateralToken0.balanceOf(user1));
// invariant totalSupplyMoreThanBalance2_shareDebtToken0(address user0, address user1)
//     user0 != user1 => shareDebtToken0.totalSupply() >= require_uint256(shareDebtToken0.balanceOf(user0) + shareDebtToken0.balanceOf(user1));
// invariant totalSupplyMoreThanBalance2_siloToken0(address user0, address user1)
//     user0 != user1 => silo0.totalSupply() >= require_uint256(silo0.balanceOf(user0) + silo0.balanceOf(user1));
// invariant totalSupplyMoreThanBalance2_token1(address user0, address user1)
//     user0 != user1 => token1.totalSupply() >= require_uint256(token1.balanceOf(user0) + token1.balanceOf(user1));
// invariant totalSupplyMoreThanBalance2_shareProtectedToken1(address user0, address user1)
//     user0 != user1 => shareProtectedCollateralToken1.totalSupply() >= require_uint256(shareProtectedCollateralToken1.balanceOf(user0) + shareProtectedCollateralToken1.balanceOf(user1));
// invariant totalSupplyMoreThanBalance2_shareDebtToken1(address user0, address user1)
//     user0 != user1 => shareDebtToken1.totalSupply() >= require_uint256(shareDebtToken1.balanceOf(user0) + shareDebtToken1.balanceOf(user1));
// invariant totalSupplyMoreThanBalance2_siloToken1(address user0, address user1)
//     user0 != user1 => silo1.totalSupply() >= require_uint256(silo1.balanceOf(user0) + silo1.balanceOf(user1));
