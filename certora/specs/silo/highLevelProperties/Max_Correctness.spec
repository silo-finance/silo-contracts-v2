import "../_common/CompleteSiloSetup.spec";
import "../_common/IsSiloFunction.spec";
import "../_common/SiloMethods.spec";
import "../_common/Helpers.spec";
import "../_common/CommonSummarizations.spec";
import "../../_simplifications/Oracle_quote_one.spec";
import "../../_simplifications/Silo_isSolvent_ghost.spec";
import "../../_simplifications/SimplifiedGetCompoundInterestRateAndUpdate.spec";

rule HLP_MaxMintCorrectness(env e, address receiver)
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

rule HLP_MaxRedeemCorrectness(env e, address receiver)
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

rule HLP_MaxDepositCorrectness(env e, address receiver)
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

rule HLP_MaxWithdrawCorrectness(env e, address receiver)
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

rule HLP_MaxBorrowCorrectness(env e, address receiver)
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