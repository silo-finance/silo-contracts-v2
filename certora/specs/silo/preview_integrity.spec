/* Integrity of preview functions */

import "../previousAudits/CompleteSiloSetup.spec";

methods {
    // ---- `IInterestRateModel` -----------------------------------------------
    // Since `getCompoundInterestRateAndUpdate` is not view, this is not strictly sound.
    function _.getCompoundInterestRateAndUpdate(
        uint256 _collateralAssets,
        uint256 _debtAssets,
        uint256 _interestRateTimestamp
    ) external => NONDET;

    // ---- `ISiloOracle` ------------------------------------------------------
    // NOTE: Since `beforeQuote` is not a view function, strictly speaking this is unsound.
    function _.beforeQuote(address) external => NONDET DELETE;
}

rule HLP_PreviewMintCorrectness(address receiver)
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

    // 
    assert assetsReported >= assetsPaid;
}

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

    // 
    assert assetsReported <= assetsReceived;
}

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

    // 
    assert sharesReported <= sharesReceived;
}

rule HLP_PreviewWithdrawCorrectness(address receiver)
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
    assert sharesPaid <= sharesReported;
}

rule HLP_PreviewBorrowCorrectness(address receiver)
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
    assert debtSharesReported >= debtSharesReceived;
}

rule HLP_PreviewRepayCorrectness(address receiver)
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
    assert debtSharesReported <= debtSharesRepaid;
}

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

/// the strict rules are the same as above just with equalities.

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

    // 
    assert assetsReported == assetsPaid;
}

rule HLP_PreviewRedeemCorrectness_strict(address receiver)
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

    // 
    assert assetsReported == assetsReceived;
}

rule HLP_PreviewDepositCorrectness_strict(address receiver)
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

    // 
    assert sharesReported == sharesReceived;
}

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

rule HLP_PreviewBorrowSharesCorrectness_strict(address receiver)
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
    assert assetsReported == assetsReceived;
}

rule HLP_PreviewRepaySharesCorrectness_strict(address receiver)
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
    assert assetsReported == assetsPaid;
}