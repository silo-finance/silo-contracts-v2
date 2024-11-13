import "../summaries/two_silos_summaries.spec";
import "../summaries/siloconfig_dispatchers.spec";
import "../summaries/tokens_dispatchers.spec";
import "../summaries/safe-approximations.spec";

import "../requirements/tokens_requirements.spec";
import "../previousAudits/CompleteSiloSetup.spec";

// The ERC4626 spec doesn't require that max{method} is as close as possible to the real bound.
// I.e. it can happen that maxBorrow(user) = X; and borrow(user, X+1) still goes through
// However Silo's code is supposed to abide by these.

rule HLP_MaxMint_reverts(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);
    
    uint256 maxShares = maxMint(e, receiver);
    uint256 shares;
    require shares > maxShares;
    uint256 assetsPaid = mint@withrevert(e, shares, receiver);
    assert lastReverted;
}

rule HLP_MaxRedeem_reverts(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);

    uint256 maxShares = maxRedeem(e, e.msg.sender);
    uint256 shares;
    require shares > maxShares;
    uint256 assetsReceived = redeem@withrevert(e, shares, receiver, e.msg.sender);
    assert lastReverted;
}

rule HLP_MaxDeposit_reverts(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);
    
    uint256 maxAssets = maxDeposit(e, receiver);
    uint256 assets;
    require assets > maxAssets;
    uint256 sharesReceived = deposit@withrevert(e, assets, receiver);
    assert lastReverted;
}

rule HLP_MaxWithdraw_reverts(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);
    
    uint256 maxAssets = maxWithdraw(e, e.msg.sender);
    uint256 assets;
    require assets > maxAssets;
    uint256 sharesPaid = withdraw@withrevert(e, assets, receiver, e.msg.sender);
    assert lastReverted;
}

rule HLP_MaxBorrow_reverts(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);
    
    uint256 maxAssets = maxBorrow(e, e.msg.sender);
    uint256 assets;
    require assets > maxAssets;
    uint256 debtReceived = borrow@withrevert(e, assets, receiver, e.msg.sender);
    assert lastReverted;
}

rule HLP_MaxRepay_reverts(env e, address borrower)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(borrower);
    totalSupplyMoreThanBalance(e.msg.sender);

    uint maxAssets = maxRepay(e, borrower);
    uint256 assets;
    require assets > maxAssets;
    uint256 shares = repay@withrevert(e, assets, borrower);
    assert lastReverted;
}

rule HLP_MaxRepayShares_reverts(env e, address borrower)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(borrower);
    totalSupplyMoreThanBalance(e.msg.sender);

    uint maxShares = maxRepayShares(e, borrower);
    uint256 shares;
    require shares > maxShares;
    mathint assets = repayShares@withrevert(e, shares, borrower);

    assert lastReverted;
}

rule HLP_MaxBorrowSameAsset_reverts(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);
    
    uint256 maxAssets = maxBorrowSameAsset(e, e.msg.sender);
    uint256 assets;
    require assets > maxAssets;
    uint256 debtReceived = borrowSameAsset@withrevert(e, assets, receiver, e.msg.sender);
    assert lastReverted;
}

// borrow() user borrows maxAssets returned by maxBorrow, 
// borrow should not revert because of solvency check
rule maxBorrow_noRevert(env e)
{
    address user; address receiver;
    uint256 maxB = maxBorrow(e, user);

    silosTimestampSetupRequirements(e);
    nonSceneAddressRequirements(receiver);
    totalSuppliesMoreThanBalances(receiver, silo0);

    _ = borrow@withrevert(e, maxB, receiver, user);
    assert !lastReverted;
}

// maxRepay() should never return more than totalAssets[AssetType.Debt]
rule maxRepay_neverGreaterThanTotalDebt(env e)
{
    silosTimestampSetupRequirements(e);
    address user;
    uint res = maxRepay(e, user);
    uint max = silo0.getTotalAssetsStorage(ISilo.AssetType.Debt);
    assert res <= max;
}

// result of maxRedeem() used as input to redeem() should never revert
rule HLP_MaxRedeem_noRevert(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);

    uint256 maxShares = maxRedeem(e, e.msg.sender);
    uint256 assetsReceived = redeem@withrevert(e, maxShares, receiver, e.msg.sender);
    assert !lastReverted;
}

// result of maxRedeem() should never be more than share token balanceOf user
rule HLP_MaxRedeem_noGreaterThanBalance(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);

    uint sharesBalance = silo0.balanceOf(e.msg.sender);
    uint256 maxShares = maxRedeem(e, e.msg.sender);
    
    assert maxShares <= sharesBalance;
}

// repaying with maxRepay() value should burn all user share debt token balance
rule maxRepay_burnsAllDebt(env e, address user)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(user);
    totalSupplyMoreThanBalance(e.msg.sender);

    uint maxAssets = maxRepay(e, user);
    uint256 shares = repay(e, maxAssets, user);    // this did not revert
    uint debtAfter = shareDebtToken0.balanceOf(user);

    assert debtAfter == 0;
}

// result of maxWithdraw() used as input to withdraw() should never revert
rule maxWithdraw_noRevert(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);
    
    uint256 maxAssets = maxWithdraw(e, e.msg.sender);
    uint256 sharesPaid = withdraw@withrevert(e, maxAssets, receiver, e.msg.sender);
    assert !lastReverted;
}

// result of maxWithdraw() should never be more than liquidity of the Silo
rule maxWithdraw_noGreaterThanLiquidity(env e)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(e.msg.sender);
    
    uint totalCollateral = silo0.getTotalAssetsStorage(ISilo.AssetType.Collateral);
    uint totalDebt = silo0.getTotalAssetsStorage(ISilo.AssetType.Debt);
    //mathint liquidity = max(0, totalCollateral - totalDebt);
    uint liquidity = getLiquidity(e);

    uint256 maxAssets = maxWithdraw(e, e.msg.sender);
    
    assert maxAssets <= liquidity;
}

function max(mathint a, mathint b) returns mathint
{
    if (a < b) return b;
    return a;
}

