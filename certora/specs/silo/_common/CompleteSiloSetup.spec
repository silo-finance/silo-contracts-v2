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
