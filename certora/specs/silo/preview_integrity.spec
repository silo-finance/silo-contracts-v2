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

// ---- Rules ------------------------------------------------------------------

// https://vaas-stg.certora.com/output/39601/279d56c263dd40aa9a7aa35d7584207f?anonymousKey=e8ccf0ac47d0313b312ea7aefd6505c52a42b4a9
rule HLP_PreviewMintCorrectness_strict(address receiver)
{
    env e;

    // Block time-stamp >= interest rate time-stamp
    silosTimestampSetupRequirements(e);
    // receiver is not one of the contracts in the scene
    nonSceneAddressRequirements(receiver);
    totalSuppliesMoreThanBalances(receiver, silo0);
    
    uint256 shares;
    uint256 assetsReported = previewMint(e, shares);
    uint256 assetsPaid = mint(e, shares, receiver);

    assert assetsReported == assetsPaid;
}

// https://vaas-stg.certora.com/output/39601/8467dce7a10046f39282f283f9ac09de?anonymousKey=3089ebc0a4b14db2e0a3294e9813dc5c3f46fe73
rule HLP_PreviewRedeemCorrectness(address receiver)
{
    env e;

    // Block time-stamp >= interest rate time-stamp
    silosTimestampSetupRequirements(e);
    // receiver is not one of the contracts in the scene
    nonSceneAddressRequirements(receiver);
    totalSuppliesMoreThanBalances(receiver, silo0);
    
    uint256 shares;
    uint256 assetsReported = previewRedeem(e, shares);
    uint256 assetsReceived = redeem(e, shares, receiver, e.msg.sender);

    assert assetsReported <= assetsReceived;
}

// https://vaas-stg.certora.com/output/39601/4cd9004431c04ec29b0f1253ab2d4b9d?anonymousKey=51b1bb99004a4e1431153084ae66ee103898041c
rule HLP_PreviewDepositCorrectness(address receiver)
{
    env e;

    // Block time-stamp >= interest rate time-stamp
    silosTimestampSetupRequirements(e);
    // receiver is not one of the contracts in the scene
    nonSceneAddressRequirements(receiver);
    totalSuppliesMoreThanBalances(receiver, silo0);
    
    uint256 assets;
    uint256 sharesReported = previewDeposit(e, assets);
    uint256 sharesReceived = deposit(e, assets, receiver);

    assert sharesReported <= sharesReceived;
}

// https://vaas-stg.certora.com/output/39601/07221c6c9de743c3b08c01cb3a8377b9?anonymousKey=786b99ae7a9307008c8dee20fec2c7ff17ea37ad
rule HLP_PreviewWithdrawCorrectness_strict(address receiver)
{
    env e;

    // Block time-stamp >= interest rate time-stamp
    silosTimestampSetupRequirements(e);
    // receiver is not one of the contracts in the scene
    nonSceneAddressRequirements(receiver);
    totalSuppliesMoreThanBalances(receiver, silo0);
    
    uint256 assets;
    uint256 sharesReported = previewWithdraw(e, assets);
    uint256 sharesPaid = withdraw(e, assets, receiver, e.msg.sender);
    assert sharesPaid == sharesReported;
}

// https://vaas-stg.certora.com/output/39601/810dd36b243d45a3a6abd7ea33955d53?anonymousKey=a85bd2bb742cfddc8e6a8022efd2d73d0a2bf449
rule HLP_PreviewBorrowCorrectness_strict(address receiver)
{
    env e;

    // Block time-stamp >= interest rate time-stamp
    silosTimestampSetupRequirements(e);
    // receiver is not one of the contracts in the scene
    nonSceneAddressRequirements(receiver);
    totalSuppliesMoreThanBalances(receiver, silo0);
    
    // bool sameAsset;
    uint256 assets;
    uint256 debtSharesReported = previewBorrow(e, assets);
    uint256 debtSharesReceived = borrow(e, assets, receiver, e.msg.sender); // , sameAsset);
    assert debtSharesReported == debtSharesReceived;
}

// https://vaas-stg.certora.com/output/39601/c718dc9eb5344cd490fe2964e9823fc4?anonymousKey=64eb2c318bf859e745eb11321eae6665d6abca68
rule HLP_PreviewRepayCorrectness_strict(address receiver)
{
    env e;

    // Block time-stamp >= interest rate time-stamp
    silosTimestampSetupRequirements(e);
    // receiver is not one of the contracts in the scene
    nonSceneAddressRequirements(receiver);
    totalSuppliesMoreThanBalances(receiver, silo0);
    
    uint256 assets;
    uint256 debtSharesReported = previewRepay(e, assets);
    uint256 debtSharesRepaid = repay(e, assets, receiver);
    assert debtSharesReported == debtSharesRepaid;
}

// https://vaas-stg.certora.com/output/39601/ae8e0698ba9a4460a4835f191c72c56d?anonymousKey=1cad83d63ba20cd95b2a970bf152d7db4e5f35e8
rule HLP_PreviewBorrowSharesCorrectness(address receiver)
{
    env e;

    // Block time-stamp >= interest rate time-stamp
    silosTimestampSetupRequirements(e);
    // receiver is not one of the contracts in the scene
    nonSceneAddressRequirements(receiver);
    totalSuppliesMoreThanBalances(receiver, silo0);
    
    // bool sameAsset;
    uint256 shares;
    uint256 assetsReported = previewBorrowShares(e, shares);
    uint256 assetsReceived = borrowShares(e, shares, receiver, e.msg.sender); // , sameAsset);
    assert assetsReported <= assetsReceived;
}

// https://vaas-stg.certora.com/output/39601/c89c20d3d90245fe8aee0956feb713a6?anonymousKey=63b4e03f2782e5689917bf767b5ec220d14f4287
rule HLP_PreviewRepaySharesCorrectness(address receiver)
{
    env e;

    // Block time-stamp >= interest rate time-stamp
    silosTimestampSetupRequirements(e);
    // receiver is not one of the contracts in the scene
    nonSceneAddressRequirements(receiver);
    totalSuppliesMoreThanBalances(receiver, silo0);
    
    uint256 shares;
    uint256 assetsReported = previewRepayShares(e, shares);
    uint256 assetsPaid = repayShares(e, shares, receiver);
    assert assetsReported >= assetsPaid;
}