using Silo0 as silo0;
using Silo1 as silo1;
using Token0 as token0;
using Token1 as token1;
using ShareDebtToken0 as shareDebtToken0;
using ShareDebtToken1 as shareDebtToken1;
using ShareProtectedCollateralToken0 as shareProtectedCollateralToken0;
using ShareProtectedCollateralToken1 as shareProtectedCollateralToken1;

// from Shoham
// we probably not need both of these
// I'd prefer to have these usings in a single file only and import it where needed
using Silo0 as silo0_R;
using Silo1 as silo1_R;
using Token0 as token0_R;
using Token1 as token1_R;
using ShareDebtToken0 as shareDebtToken0_R;
using ShareProtectedCollateralToken0 as shareProtectedCollateralToken0_R;
using ShareDebtToken1 as shareDebtToken1_R;
using ShareProtectedCollateralToken1 as shareProtectedCollateralToken1_R;
using SiloConfig as siloConfig_R;

function SafeAssumptions(env e) 
{
    completeSiloSetupForEnv(e);
    requireEnvFreeInvariants();
    requireEnvInvariants(e);
}

function SafeAssumptions(env e, address user) 
{
    SafeAssumptions(e);
    requireEnvAndUserInvariants(e, user);
}

function completeSiloSetupForEnv(env e) {
    configForEightTokensSetupRequirements();

    nonSceneAddressRequirements(e.msg.sender);
    // require e.msg.sender != shareDebtToken0;
    // require e.msg.sender != shareDebtToken1;
    // require e.msg.sender != shareProtectedCollateralToken0;
    // require e.msg.sender != shareProtectedCollateralToken1;
    // require e.msg.sender != token0;
    // require e.msg.sender != token1;
    
    silosTimestampSetupRequirements(e);
    // we can not have block.timestamp less than interestRateTimestamp
    // require e.block.timestamp < (1 << 64);
    // require e.block.timestamp >= silo0.getSiloDataInterestRateTimestamp(e);
    // require e.block.timestamp >= silo1.getSiloDataInterestRateTimestamp(e);
}

//////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////
/////  basic invariants
////////////////////////////

//there are shares if and only if there are tokens
//  otherwise there are CEXs where borrow(a lot); repay(a little); removes all debt from the user, etc.
invariant shareDebtToken0_tracked()         shareDebtToken0.totalSupply() == 0 <=> silo0.getTotalAssetsStorage(ISilo.AssetType.Debt) == 0;
invariant shareProtectedToken0_tracked()    shareProtectedCollateralToken0.totalSupply() == 0 <=> silo0.getTotalAssetsStorage(ISilo.AssetType.Protected) == 0;
invariant siloToken0_tracked()              silo0.totalSupply() == 0 <=> silo0.getTotalAssetsStorage(ISilo.AssetType.Collateral) == 0;
invariant shareDebtToken1_tracked()         shareDebtToken1.totalSupply() == 0 <=> silo1.getTotalAssetsStorage(ISilo.AssetType.Debt) == 0;
invariant shareProtectedToken1_tracked()    shareProtectedCollateralToken1.totalSupply() == 0 <=> silo1.getTotalAssetsStorage(ISilo.AssetType.Protected) == 0;
invariant siloToken1_tracked()              silo1.totalSupply() == 0 <=> silo1.getTotalAssetsStorage(ISilo.AssetType.Collateral) == 0;

// total supply is more than balance - 1 user
invariant totalSupplyMoreThanBalance_token0(address user)               token0.totalSupply() >= token0.balanceOf(user);
invariant totalSupplyMoreThanBalance_shareProtectedToken0(address user) shareProtectedCollateralToken0.totalSupply() >= shareProtectedCollateralToken0.balanceOf(user);
invariant totalSupplyMoreThanBalance_shareDebtToken0(address user)      shareDebtToken0.totalSupply() >= shareDebtToken0.balanceOf(user);
invariant totalSupplyMoreThanBalance_siloToken0(address user)           silo0.totalSupply() >= silo0.balanceOf(user);
invariant totalSupplyMoreThanBalance_token1(address user)               token1.totalSupply() >= token1.balanceOf(user);
invariant totalSupplyMoreThanBalance_shareProtectedToken1(address user) shareProtectedCollateralToken1.totalSupply() >= shareProtectedCollateralToken1.balanceOf(user);
invariant totalSupplyMoreThanBalance_shareDebtToken1(address user)      shareDebtToken1.totalSupply() >= shareDebtToken1.balanceOf(user);
invariant totalSupplyMoreThanBalance_siloToken1(address user)           silo1.totalSupply() >= silo1.balanceOf(user);

// total supply is more than balance - 2 users
invariant totalSupplyMoreThanBalance2_token0(address user0, address user1)
    user0 != user1 => token0.totalSupply() >= require_uint256(token0.balanceOf(user0) + token0.balanceOf(user1));
invariant totalSupplyMoreThanBalance2_shareProtectedToken0(address user0, address user1)
    user0 != user1 => shareProtectedCollateralToken0.totalSupply() >= require_uint256(shareProtectedCollateralToken0.balanceOf(user0) + shareProtectedCollateralToken0.balanceOf(user1));
invariant totalSupplyMoreThanBalance2_shareDebtToken0(address user0, address user1)
    user0 != user1 => shareDebtToken0.totalSupply() >= require_uint256(shareDebtToken0.balanceOf(user0) + shareDebtToken0.balanceOf(user1));
invariant totalSupplyMoreThanBalance2_siloToken0(address user0, address user1)
    user0 != user1 => silo0.totalSupply() >= require_uint256(silo0.balanceOf(user0) + silo0.balanceOf(user1));
invariant totalSupplyMoreThanBalance2_token1(address user0, address user1)
    user0 != user1 => token1.totalSupply() >= require_uint256(token1.balanceOf(user0) + token1.balanceOf(user1));
invariant totalSupplyMoreThanBalance2_shareProtectedToken1(address user0, address user1)
    user0 != user1 => shareProtectedCollateralToken1.totalSupply() >= require_uint256(shareProtectedCollateralToken1.balanceOf(user0) + shareProtectedCollateralToken1.balanceOf(user1));
invariant totalSupplyMoreThanBalance2_shareDebtToken1(address user0, address user1)
    user0 != user1 => shareDebtToken1.totalSupply() >= require_uint256(shareDebtToken1.balanceOf(user0) + shareDebtToken1.balanceOf(user1));
invariant totalSupplyMoreThanBalance2_siloToken1(address user0, address user1)
    user0 != user1 => silo1.totalSupply() >= require_uint256(silo1.balanceOf(user0) + silo1.balanceOf(user1));

// sum of [(normal)shares + protected shares + balance of any user] is no more than totalSupply of the token
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
    requireInvariant totalSupplyMoreThanBalance_token0(e.msg.sender);           
    requireInvariant totalSupplyMoreThanBalance_shareProtectedToken0(e.msg.sender);
    requireInvariant totalSupplyMoreThanBalance_shareDebtToken0(e.msg.sender);      
    requireInvariant totalSupplyMoreThanBalance_siloToken0(e.msg.sender);           
    requireInvariant totalSupplyMoreThanBalance_token1(e.msg.sender);               
    requireInvariant totalSupplyMoreThanBalance_shareProtectedToken1(e.msg.sender); 
    requireInvariant totalSupplyMoreThanBalance_shareDebtToken1(e.msg.sender);     
    requireInvariant totalSupplyMoreThanBalance_siloToken1(e.msg.sender);      

    requireInvariant token0Distribution(e.msg.sender);
    requireInvariant token1Distribution(e.msg.sender);
    requireInvariant debt0ThenHasCollateral(e.msg.sender);
    requireInvariant debt1ThenHasCollateral(e.msg.sender);
}

// requires all the invariants with env and user defined bellow.
// !!  if you add more, also require them here    !!
function requireEnvAndUserInvariants(env e, address user)
{
    requireInvariant totalSupplyMoreThanBalance_token0(user);           
    requireInvariant totalSupplyMoreThanBalance_shareProtectedToken0(user);
    requireInvariant totalSupplyMoreThanBalance_shareDebtToken0(user);      
    requireInvariant totalSupplyMoreThanBalance_siloToken0(user);           
    requireInvariant totalSupplyMoreThanBalance_token1(user);               
    requireInvariant totalSupplyMoreThanBalance_shareProtectedToken1(user); 
    requireInvariant totalSupplyMoreThanBalance_shareDebtToken1(user);     
    requireInvariant totalSupplyMoreThanBalance_siloToken1(user);        

    requireInvariant totalSupplyMoreThanBalance2_token0(user, e.msg.sender);           
    requireInvariant totalSupplyMoreThanBalance2_shareProtectedToken0(user, e.msg.sender);
    requireInvariant totalSupplyMoreThanBalance2_shareDebtToken0(user, e.msg.sender);      
    requireInvariant totalSupplyMoreThanBalance2_siloToken0(user, e.msg.sender);           
    requireInvariant totalSupplyMoreThanBalance2_token1(user, e.msg.sender);               
    requireInvariant totalSupplyMoreThanBalance2_shareProtectedToken1(user, e.msg.sender); 
    requireInvariant totalSupplyMoreThanBalance2_shareDebtToken1(user, e.msg.sender);     
    requireInvariant totalSupplyMoreThanBalance2_siloToken1(user, e.msg.sender);    

    requireInvariant token0Distribution(user);
    requireInvariant token1Distribution(user);
    requireInvariant debt0ThenHasCollateral(user);
    requireInvariant debt1ThenHasCollateral(user);
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
    totalCollateralAssets, totalProtectedAssets = getCollateralAndProtectedTotalsStorage(e);  
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
    f.selector == sig:accrueInterest().selector ||
    f.selector == sig:borrow(uint256,address,address).selector ||
    f.selector == sig:borrowShares(uint256,address,address).selector ||
    f.selector == sig:deposit(uint256,address).selector ||
    f.selector == sig:deposit(uint256,address,ISilo.CollateralType).selector ||
    f.selector == sig:flashLoan(address,address,uint256,bytes).selector ||
    // f.selector == sig:leverage(uint256,address,address,bytes).selector ||
    // f.selector == sig:liquidationCall(address,address,address,uint256,bool).selector ||
    f.selector == sig:mint(uint256,address).selector ||
    f.selector == sig:mint(uint256,address,ISilo.CollateralType).selector ||
    f.selector == sig:redeem(uint256,address,address).selector ||
    f.selector == sig:redeem(uint256,address,address,ISilo.CollateralType).selector ||
    f.selector == sig:repay(uint256,address).selector ||
    f.selector == sig:repayShares(uint256,address).selector ||
    f.selector == sig:transitionCollateral(uint256,address,ISilo.CollateralType).selector ||
    f.selector == sig:withdrawFees().selector ||
    f.selector == sig:withdraw(uint256,address,address).selector ||
    f.selector == sig:withdraw(uint256,address,address,ISilo.CollateralType).selector;

definition canDecreaseAccrueInterest(method f) returns bool =
    f.selector == sig:accrueInterest().selector ||
    f.selector == sig:borrow(uint256,address,address).selector ||
    f.selector == sig:borrowShares(uint256,address,address).selector ||
    f.selector == sig:deposit(uint256,address).selector ||
    f.selector == sig:deposit(uint256,address,ISilo.CollateralType).selector ||
    // f.selector == sig:leverage(uint256,address,address,bytes).selector ||
    f.selector == sig:mint(uint256,address).selector ||
    f.selector == sig:mint(uint256,address,ISilo.CollateralType).selector ||
    // f.selector == sig:liquidationCall(address,address,address,uint256,bool).selector ||
    f.selector == sig:transitionCollateral(uint256,address,ISilo.CollateralType).selector ||
    f.selector == sig:redeem(uint256,address,address).selector ||
    f.selector == sig:redeem(uint256,address,address,ISilo.CollateralType).selector ||
    f.selector == sig:repay(uint256,address).selector ||
    f.selector == sig:repayShares(uint256,address).selector ||
    f.selector == sig:withdraw(uint256,address,address).selector ||
    f.selector == sig:withdrawFees().selector ||
    f.selector == sig:withdraw(uint256,address,address,ISilo.CollateralType).selector;

definition canIncreaseTimestamp(method f) returns bool =
    f.selector == sig:accrueInterest().selector ||
    f.selector == sig:borrow(uint256,address,address).selector ||
    f.selector == sig:borrowShares(uint256,address,address).selector ||
    // f.selector == sig:leverage(uint256,address,address,bytes).selector ||
    // f.selector == sig:liquidationCall(address,address,address,uint256,bool).selector ||
    f.selector == sig:transitionCollateral(uint256,address,ISilo.CollateralType).selector ||
    f.selector == sig:withdraw(uint256,address,address).selector ||
    f.selector == sig:withdraw(uint256,address,address,ISilo.CollateralType).selector ||
    f.selector == sig:deposit(uint256,address).selector ||
    f.selector == sig:deposit(uint256,address,ISilo.CollateralType).selector ||
    f.selector == sig:mint(uint256,address).selector ||
    f.selector == sig:mint(uint256,address,ISilo.CollateralType).selector ||
    f.selector == sig:redeem(uint256,address,address).selector ||
    f.selector == sig:redeem(uint256,address,address,ISilo.CollateralType).selector ||
    f.selector == sig:repay(uint256,address).selector ||
    f.selector == sig:repayShares(uint256,address).selector;

definition canDecreaseTimestamp(method f) returns bool =
    false;

definition canIncreaseSharesBalance(method f) returns bool =
    f.selector == sig:mint(uint256,address,ISilo.CollateralType).selector ||
    f.selector == sig:mint(uint256,address).selector ||
    f.selector == sig:transfer(address,uint256).selector ||
    f.selector == sig:transferFrom(address,address,uint256).selector ||
    f.selector == sig:transitionCollateral(uint256,address,ISilo.CollateralType).selector ||
    f.selector == sig:deposit(uint256,address,ISilo.CollateralType).selector ||
    f.selector == sig:deposit(uint256,address).selector;

definition canDecreaseSharesBalance(method f) returns bool =
    f.selector == sig:redeem(uint256,address,address).selector ||
    f.selector == sig:redeem(uint256,address,address,ISilo.CollateralType).selector ||
    f.selector == sig:transfer(address,uint256).selector ||
    f.selector == sig:transferFrom(address,address,uint256).selector ||
    f.selector == sig:transitionCollateral(uint256,address,ISilo.CollateralType).selector ||
    f.selector == sig:withdraw(uint256,address,address).selector ||
    f.selector == sig:withdraw(uint256,address,address,ISilo.CollateralType).selector;
    //f.selector == sig:withdrawCollateralsToLiquidator(uint256,uint256,address,address,bool).selector;
    
definition canIncreaseProtectedAssets(method f) returns bool =
    f.selector == sig:deposit(uint256,address,ISilo.CollateralType).selector ||
    f.selector == sig:mint(uint256,address,ISilo.CollateralType).selector ||
    f.selector == sig:transitionCollateral(uint256,address,ISilo.CollateralType).selector;

definition canDecreaseProtectedAssets(method f) returns bool =
    f.selector == sig:redeem(uint256,address,address,ISilo.CollateralType).selector ||
    f.selector == sig:withdraw(uint256,address,address,ISilo.CollateralType).selector ||
    //f.selector == sig:withdrawCollateralsToLiquidator(uint256,uint256,address,address,bool).selector ||
    f.selector == sig:transitionCollateral(uint256,address,ISilo.CollateralType).selector;

definition canIncreaseTotalCollateral(method f) returns bool = 
    f.selector == sig:mint(uint256,address,ISilo.CollateralType).selector ||
    f.selector == sig:mint(uint256,address).selector ||
    f.selector == sig:deposit(uint256,address,ISilo.CollateralType).selector ||
    f.selector == sig:deposit(uint256,address).selector ||
    f.selector == sig:transitionCollateral(uint256,address,ISilo.CollateralType).selector; 

definition canDecreaseTotalCollateral(method f) returns bool =
    f.selector == sig:redeem(uint256,address,address,ISilo.CollateralType).selector ||
    f.selector == sig:withdraw(uint256,address,address,ISilo.CollateralType).selector;
    //f.selector == sig:liquidationCall(address,address,address,uint256,bool).selector;

definition canIncreaseTotalProtectedCollateral(method f) returns bool = 
    canIncreaseTotalCollateral(f);

definition canDecreaseTotalProtectedCollateral(method f) returns bool =
    f.selector == sig:redeem(uint256,address,address,ISilo.CollateralType).selector ||
    f.selector == sig:withdraw(uint256,address,address,ISilo.CollateralType).selector;
    //f.selector == sig:liquidationCall(address,address,address,uint256,bool).selector;
    //f.selector == sig:transitionCollateral(uint256,address,ISilo.CollateralType).selector;

definition canIncreaseTotalDebt(method f) returns bool =
    f.selector == sig:borrow(uint256,address,address).selector ||
    f.selector == sig:borrowShares(uint256,address,address).selector;
    //f.selector == sig:leverage(uint256,address,address,bytes).selector;

definition canDecreaseTotalDebt(method f) returns bool =
    f.selector == sig:repay(uint256,address).selector ||
    f.selector == sig:repayShares(uint256,address).selector;

definition canIncreaseDebt(method f) returns bool =
    f.selector == sig:borrow(uint256,address,address).selector ||
    f.selector == sig:borrowShares(uint256,address,address).selector;

definition canDecreaseDebt(method f) returns bool =
    f.selector == sig:repay(uint256,address).selector ||
    f.selector == sig:repayShares(uint256,address).selector;


//////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////
/// ideas, left over pices of code
//////////////////////////////


// prove that (accrueInterest; f();) has the same effect as f()
// afterwards add require that accrueInterest was already called before.
// It will simplify some methods, save runtime

// getExactLiquidationAmount can be simplified
// just assume that the resulting LTV is above the liquidation treshold (solvent LTV)


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


//////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////
/// from Shoham
//////////////////////////////

/// Prevents having block timestamp less than interest rate timestamp
function silosTimestampSetupRequirements(env e) {
    require require_uint64(e.block.timestamp) >= silo0_R.getSiloDataInterestRateTimestamp(e);
    require require_uint64(e.block.timestamp) >= silo1_R.getSiloDataInterestRateTimestamp(e);
}

/// Given address is not one of the tokens, silos or config
function nonSceneAddressRequirements(address sender) {
    require sender != silo0_R;
    require sender != silo1_R;
    require sender != siloConfig_R;

    require sender != shareDebtToken0_R;
    require sender != shareProtectedCollateralToken0_R;
    require sender != shareDebtToken1_R;
    require sender != shareProtectedCollateralToken1_R;

    require sender != token0_R;
    require sender != token1_R;
}

/// Ensures the `siloConfig` is set up properly
function configForEightTokensSetupRequirements() {
    require silo0_R.silo() == silo0_R;
    require silo0_R.config() == siloConfig_R;

    require silo1_R.silo() == silo1_R;
    require silo1_R.config() == siloConfig_R;

    require shareDebtToken0_R.silo() == silo0_R;
    require shareProtectedCollateralToken0_R.silo() == silo0_R;
    
    require silo0_R.siloConfig() == siloConfig_R;
    require shareDebtToken0_R.siloConfig() == siloConfig_R;
    require shareDebtToken0_R.siloConfig() == siloConfig_R;

    require shareDebtToken1_R.silo() == silo1_R;
    require shareProtectedCollateralToken1_R.silo() == silo1_R;
    
    require silo1_R.siloConfig() == siloConfig_R;
    require shareDebtToken1_R.siloConfig() == siloConfig_R;
    require shareDebtToken1_R.siloConfig() == siloConfig_R;
}

function totalSuppliesMoreThanBalances(address user1, address user2) {
    require user1 != user2;
    require (
        to_mathint(silo0_R.totalSupply()) >=
        silo0_R.balanceOf(user1) + silo0_R.balanceOf(user2)
    );
    require (
        to_mathint(shareDebtToken0_R.totalSupply()) >=
        shareDebtToken0_R.balanceOf(user1) + shareDebtToken0_R.balanceOf(user2)
    );
    require (
        to_mathint(shareProtectedCollateralToken0_R.totalSupply()) >=
        shareProtectedCollateralToken0_R.balanceOf(user1) +
        shareProtectedCollateralToken0_R.balanceOf(user2)
    );
    require (
        to_mathint(token0_R.totalSupply()) >=
        token0_R.balanceOf(user1) + token0_R.balanceOf(user2)
    );

    require (
        to_mathint(silo1_R.totalSupply()) >=
        silo1_R.balanceOf(user1) + silo1_R.balanceOf(user2)
    );
    require (
        to_mathint(shareDebtToken1_R.totalSupply()) >=
        shareDebtToken1_R.balanceOf(user1) + shareDebtToken1_R.balanceOf(user2)
    );
    require (
        to_mathint(shareProtectedCollateralToken1_R.totalSupply()) >=
        shareProtectedCollateralToken1_R.balanceOf(user1) +
        shareProtectedCollateralToken1_R.balanceOf(user2)
    );
    require (
        to_mathint(token1_R.totalSupply()) >=
        token1_R.balanceOf(user1) + token1_R.balanceOf(user2)
    );
}

function totalSuppliesMoreThanThreeBalances(address user1, address user2, address user3) {
    require user1 != user2 && user1 != user3 && user2 != user3;
    require (
        to_mathint(silo0_R.totalSupply()) >=
        silo0_R.balanceOf(user1) + silo0_R.balanceOf(user2) + silo0_R.balanceOf(user3)
    );
    require (
        to_mathint(shareDebtToken0_R.totalSupply()) >=
        shareDebtToken0_R.balanceOf(user1) +
        shareDebtToken0_R.balanceOf(user2) +
        shareDebtToken0_R.balanceOf(user3)
    );
    require (
        to_mathint(shareProtectedCollateralToken0_R.totalSupply()) >=
        shareProtectedCollateralToken0_R.balanceOf(user1) +
        shareProtectedCollateralToken0_R.balanceOf(user2) +
        shareProtectedCollateralToken0_R.balanceOf(user3)
    );
    require (
        to_mathint(token0_R.totalSupply()) >=
        token0_R.balanceOf(user1) + token0_R.balanceOf(user2) + token0_R.balanceOf(user3)
    );

    require (
        to_mathint(silo1_R.totalSupply()) >=
        silo1_R.balanceOf(user1) + silo1_R.balanceOf(user2) + silo1_R.balanceOf(user3)
    );
    require (
        to_mathint(shareDebtToken1_R.totalSupply()) >=
        shareDebtToken1_R.balanceOf(user1) +
        shareDebtToken1_R.balanceOf(user2) +
        shareDebtToken1_R.balanceOf(user3)
    );
    require (
        to_mathint(shareProtectedCollateralToken1_R.totalSupply()) >=
        shareProtectedCollateralToken1_R.balanceOf(user1) +
        shareProtectedCollateralToken1_R.balanceOf(user2) +
        shareProtectedCollateralToken1_R.balanceOf(user3)
    );
    require (
        to_mathint(token1_R.totalSupply()) >=
        token1_R.balanceOf(user1) + token1_R.balanceOf(user2) + token1_R.balanceOf(user3)
    );
}