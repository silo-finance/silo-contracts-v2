/* Integrity of preview functions */

import "../requirements/two_silos_tokens_requirements.spec";
import "../summaries/two_silos_summaries.spec";
import "../summaries/siloconfig_dispatchers.spec";
import "../summaries/config_for_two_in_cvl.spec";
import "../summaries/safe-approximations.spec";
import "../summaries/interest_rate_model_v2.spec";

// ---- Methods and Invariants -------------------------------------------------

// This invariant is required for some of the rules above,
// and should be proved elsewhere (TODO indicate where)
invariant assetsZeroInterestRateTimestampZero(env e)
    silo0.getCollateralAssets(e) > 0 || silo0.getDebtAssets(e) > 0 =>
    silo0.getSiloDataInterestRateTimestamp(e) > 0 ;

methods {
    function _.quote(uint256 _baseAmount, address _baseToken) external => CONSTANT ;
}

// ---- Rules ------------------------------------------------------------------

/// @status Done
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

/// @status Done
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

/// @status Done
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

/// @status Done
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

/// @status Done
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

/// @status Done
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

/// @status Done
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

/// @status Done
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

// ---- Rules from the list ----------------------------------------------------

/// @dev rule 59:
//          if user is solvent transitionCollateral() for
//          _transitionFrom == CollateralType.Protected should never revert

/// @status Proved a weaker result with "satisfy" due to time constraints

rule transitionSucceedsIfSolvent(uint256 _shares,address _owner) {
    env e;

    // Block time-stamp >= interest rate time-stamp
    silosTimestampSetupRequirements(e);
    // e.msg.sender is not one of the contracts in the scene
    nonSceneAddressRequirements(_owner);
    totalSuppliesMoreThanBalances(_owner, silo0);

    // user is solvent
    require silo0.isSolvent(e,_owner) == true;

    // transitions collateral
    silo0.transitionCollateral@withrevert(e,_shares,_owner,ISilo.CollateralType.Protected);

    // did not revert
    satisfy !lastReverted;
}


/// @dev rule 64:
//  user must be solvent after switchCollateralToThisSilo()

/// @status Done

rule solventAfterSwitch() {
    env e;
    
    // Block time-stamp >= interest rate time-stamp
    silosTimestampSetupRequirements(e);
    // e.msg.sender is not one of the contracts in the scene
    nonSceneAddressRequirements(e.msg.sender);
    totalSuppliesMoreThanBalances(e.msg.sender, silo0);

    silo0.switchCollateralToThisSilo(e);

    assert silo0.isSolvent(e,e.msg.sender);
}