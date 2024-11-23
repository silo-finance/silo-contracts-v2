/* Integrity of preview functions */

import "../summaries/two_silos_summaries.spec";
import "../summaries/siloconfig_dispatchers.spec";
import "../summaries/tokens_dispatchers.spec";
import "../summaries/safe-approximations.spec";
import "../summaries/config_for_two_in_cvl.spec";
import "../summaries/interest_rate_model_v2.spec";

import "../requirements/tokens_requirements.spec";

using Silo0 as silo0;
using Silo1 as silo1;
using Token0 as token0;
using Token1 as token1;
using ShareDebtToken0 as shareDebtToken0;
using ShareDebtToken1 as shareDebtToken1;

// ---- Invariants -------------------------------------------------------------

// This invariant is required for some of the rules above,
// and should be proved elsewhere (TODO indicate where)
invariant assetsZeroInterestRateTimestampZero(env e)
    silo0.getCollateralAssets(e) > 0 || silo0.getDebtAssets(e) > 0 =>
    silo0.getSiloDataInterestRateTimestamp(e) > 0 ;


// ---- Rules ------------------------------------------------------------------

/// @status Done: https://vaas-stg.certora.com/output/39601/c718bcc6d805415f83255bf440b1ef17?anonymousKey=52ff03ee66ee85abf5370119b82433e9d94c4e18
rule HLP_PreviewMintCorrectness_strict(address receiver)
{
    env e;

    // Block time-stamp >= interest rate time-stamp
    silosTimestampSetupRequirements(e);
    // receiver is not one of the contracts in the scene
    nonSceneAddressRequirements(receiver);
    totalSuppliesMoreThanBalances(receiver, silo0);

    requireInvariant assetsZeroInterestRateTimestampZero(e) ;
    
    uint256 shares;
    uint256 assetsReported = previewMint(e, shares);
    uint256 assetsPaid = mint(e, shares, receiver);

    assert assetsReported == assetsPaid;
}

/// @status Done: https://vaas-stg.certora.com/output/39601/d718e23421274125bc9e540a1e890577?anonymousKey=7bf294a459b0560234f3f13ea85704e93e934eac
rule HLP_PreviewRedeemCorrectness(address receiver)
{
    env e;

    // Block time-stamp >= interest rate time-stamp
    silosTimestampSetupRequirements(e);
    // receiver is not one of the contracts in the scene
    nonSceneAddressRequirements(receiver);
    totalSuppliesMoreThanBalances(receiver, silo0);

    requireInvariant assetsZeroInterestRateTimestampZero(e) ;
    
    uint256 shares;
    uint256 assetsReported = previewRedeem(e, shares);
    uint256 assetsReceived = redeem(e, shares, receiver, e.msg.sender);

    assert assetsReported <= assetsReceived;
}

/// @status Done: https://vaas-stg.certora.com/output/39601/f55ff4263cbd40a58b28d3601234c99e?anonymousKey=796a8296609848e1822ba7680ad2fabca71ad9e2
rule HLP_PreviewDepositCorrectness(address receiver)
{
    env e;

    // Block time-stamp >= interest rate time-stamp
    silosTimestampSetupRequirements(e);
    // receiver is not one of the contracts in the scene
    nonSceneAddressRequirements(receiver);
    totalSuppliesMoreThanBalances(receiver, silo0);

    requireInvariant assetsZeroInterestRateTimestampZero(e) ;
    
    uint256 assets;
    uint256 sharesReported = previewDeposit(e, assets);
    uint256 sharesReceived = deposit(e, assets, receiver);

    assert sharesReported <= sharesReceived;
}

/// @status Done: https://vaas-stg.certora.com/output/39601/dac3f20517bd46158890ed2e082112f8?anonymousKey=6f5deb062eb061faeadd94476742891ad43e66a8
rule HLP_PreviewWithdrawCorrectness_strict(address receiver)
{
    env e;

    // Block time-stamp >= interest rate time-stamp
    silosTimestampSetupRequirements(e);
    // receiver is not one of the contracts in the scene
    nonSceneAddressRequirements(receiver);
    totalSuppliesMoreThanBalances(receiver, silo0);

    requireInvariant assetsZeroInterestRateTimestampZero(e) ;
    
    uint256 assets;
    uint256 sharesReported = previewWithdraw(e, assets);
    uint256 sharesPaid = withdraw(e, assets, receiver, e.msg.sender);
    assert sharesPaid == sharesReported;
}

/// @status Done: https://vaas-stg.certora.com/output/39601/5f54a319b0a14f4eb7fcaf11e8b5f526?anonymousKey=98bc6736865b9a5b08b8467a11030c5b2f53975b
rule HLP_PreviewBorrowCorrectness_strict(address receiver)
{
    env e;

    // Block time-stamp >= interest rate time-stamp
    silosTimestampSetupRequirements(e);
    // receiver is not one of the contracts in the scene
    nonSceneAddressRequirements(receiver);
    totalSuppliesMoreThanBalances(receiver, silo0);

    requireInvariant assetsZeroInterestRateTimestampZero(e) ;
    
    // bool sameAsset;
    uint256 assets;
    uint256 debtSharesReported = previewBorrow(e, assets);
    uint256 debtSharesReceived = borrow(e, assets, receiver, e.msg.sender); // , sameAsset);
    assert debtSharesReported == debtSharesReceived;
}

/// @status Done: https://vaas-stg.certora.com/output/39601/9cd5865d6bb54f348227a21f66d059e3?anonymousKey=3fa36708608ed5fe351e95752dec70babf80bbae
rule HLP_PreviewRepayCorrectness_strict(address receiver)
{
    env e;

    // Block time-stamp >= interest rate time-stamp
    silosTimestampSetupRequirements(e);
    // receiver is not one of the contracts in the scene
    nonSceneAddressRequirements(receiver);
    totalSuppliesMoreThanBalances(receiver, silo0);

    requireInvariant assetsZeroInterestRateTimestampZero(e) ;
    
    uint256 assets;
    uint256 debtSharesReported = previewRepay(e, assets);
    uint256 debtSharesRepaid = repay(e, assets, receiver);
    assert debtSharesReported == debtSharesRepaid;
}

/// @status Done: https://vaas-stg.certora.com/output/39601/fa2c85488a5b43bc903f5f6955fe33a6?anonymousKey=5e67aec259990ed6dd07acc6e7ee7b3aa92b5d63
rule HLP_PreviewBorrowSharesCorrectness(address receiver)
{
    env e;

    // Block time-stamp >= interest rate time-stamp
    silosTimestampSetupRequirements(e);
    // receiver is not one of the contracts in the scene
    nonSceneAddressRequirements(receiver);
    totalSuppliesMoreThanBalances(receiver, silo0);

    requireInvariant assetsZeroInterestRateTimestampZero(e) ;
    
    // bool sameAsset;
    uint256 shares;
    uint256 assetsReported = previewBorrowShares(e, shares);
    uint256 assetsReceived = borrowShares(e, shares, receiver, e.msg.sender); // , sameAsset);
    assert assetsReported <= assetsReceived;
}

/// @status Done: https://vaas-stg.certora.com/output/39601/b62ea4cd47b24d7b9a2d40d14000ff7d?anonymousKey=1f67cd9ccc9f2ce3a1e5a509c801b9bfbb29f3e2
rule HLP_PreviewRepaySharesCorrectness(address receiver)
{
    env e;

    // Block time-stamp >= interest rate time-stamp
    silosTimestampSetupRequirements(e);
    // receiver is not one of the contracts in the scene
    nonSceneAddressRequirements(receiver);
    totalSuppliesMoreThanBalances(receiver, silo0);

    requireInvariant assetsZeroInterestRateTimestampZero(e) ;
    
    uint256 shares;
    uint256 assetsReported = previewRepayShares(e, shares);
    uint256 assetsPaid = repayShares(e, shares, receiver);
    assert assetsReported >= assetsPaid;
}
