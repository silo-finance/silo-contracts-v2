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
    require e.msg.sender != shareProtectedCollateralToken0;
    require e.msg.sender != shareDebtToken0;
    require e.msg.sender != shareCollateralToken0;
    require e.msg.sender != shareProtectedCollateralToken1;
    require e.msg.sender != shareDebtToken1;
    require e.msg.sender != shareCollateralToken1;
    require e.msg.sender != siloConfig;
    require e.msg.sender != silo0;
    require e.msg.sender != silo1;
    require e.msg.sender != token0;
    require e.msg.sender != token1;

    // we can not have block.timestamp less than interestRateTimestamp
    uint256 blockTimestamp = require_uint64(e.block.timestamp);
    require blockTimestamp >= silo0.getSiloDataInterestRateTimestamp(e);
    require blockTimestamp >= silo1.getSiloDataInterestRateTimestamp(e);
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
    f.selector == sig:withdraw(uint256,address,address,ISilo.AssetType).selector;   
    
definition canIncreaseProtectedAssets(method f) returns bool =
    f.selector == sig:deposit(uint256,address,ISilo.AssetType).selector ||
    f.selector == sig:mint(uint256,address,ISilo.AssetType).selector ||
    f.selector == sig:transitionCollateral(uint256,address,ISilo.AssetType).selector;

definition canDecreaseProtectedAssets(method f) returns bool =
    f.selector == sig:redeem(uint256,address,address,ISilo.AssetType).selector ||
    f.selector == sig:withdraw(uint256,address,address,ISilo.AssetType).selector ||
    f.selector == sig:transitionCollateral(uint256,address,ISilo.AssetType).selector;
