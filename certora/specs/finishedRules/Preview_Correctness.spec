import "../_common/CompleteSiloSetup.spec";
import "../_common/IsSiloFunction.spec";
import "../_common/SiloMethods.spec";
import "../_common/Helpers.spec";
import "../_common/CommonSummarizations.spec";
import "../_simplifications/Oracle_quote_one.spec";
//import "../_simplifications/priceOracle.spec";
//import "../_simplifications/Silo_isSolvent_ghost.spec";
import "../_simplifications/SiloSolvencyLib.spec";
import "../_simplifications/SimplifiedGetCompoundInterestRateAndUpdate.spec";

rule HLP_PreviewMintCorrectness(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);
    
    uint256 shares;
    uint256 assetsReported = previewMint(e, shares);
    uint256 assetsPaid = mint(e, shares, receiver);
    assert assetsReported >= assetsPaid;
}

rule HLP_PreviewRedeemCorrectness(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);
    
    uint256 shares;
    uint256 assetsReported = previewRedeem(e, shares);
    uint256 assetsReceived = redeem(e, shares, receiver, e.msg.sender);
    assert assetsReported <= assetsReceived;
}

rule HLP_PreviewDepositCorrectness(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);
    
    uint256 assets;
    uint256 sharesReported = previewDeposit(e, assets);
    uint256 sharesReceived = deposit(e, assets, receiver);
    assert sharesReported <= sharesReceived;
}

rule HLP_PreviewWithdrawCorrectness(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);
    
    uint256 assets;
    uint256 sharesReported = previewWithdraw(e, assets);
    uint256 sharesPaid = withdraw(e, assets, receiver, e.msg.sender);
    assert sharesPaid <= sharesReported;
}

rule HLP_PreviewBorrowCorrectness(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);
    
    bool sameAsset;
    uint256 assets;
    uint256 debtSharesReported = previewBorrow(e, assets);
    uint256 debtSharesReceived = borrow(e, assets, receiver, e.msg.sender, sameAsset);
    assert debtSharesReported >= debtSharesReceived;
}


rule HLP_PreviewRepayCorrectness(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);
    
    uint256 assets;
    uint256 debtSharesReported = previewRepay(e, assets);
    uint256 debtSharesRepaid = repay(e, assets, receiver);
    assert debtSharesReported <= debtSharesRepaid;
}

rule HLP_PreviewBorrowSharesCorrectness(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);
    
    bool sameAsset;
    uint256 shares;
    uint256 assetsReported = previewBorrowShares(e, shares);
    uint256 assetsReceived = borrowShares(e, shares, receiver, e.msg.sender, sameAsset);
    assert assetsReported <= assetsReceived;
}

rule HLP_PreviewRepaySharesCorrectness(env e, address receiver)
{
    completeSiloSetupEnv(e);
    totalSupplyMoreThanBalance(receiver);
    totalSupplyMoreThanBalance(e.msg.sender);
    
    uint256 shares;
    uint256 assetsReported = previewRepayShares(e, shares);
    uint256 assetsPaid = repayShares(e, shares, receiver);
    assert assetsReported >= assetsPaid;
}