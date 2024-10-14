import "../summaries/two_silos_summaries.spec";
import "../summaries/siloconfig_dispatchers.spec";
import "../summaries/tokens_dispatchers.spec";
import "../summaries/sound.spec";

import "../requirements/tokens_requirements.spec";

using Silo0 as silo0;
using Silo1 as silo1;
using Token0 as token0;
using Token1 as token1;
using ShareDebtToken0 as shareDebtToken0;
using ShareDebtToken1 as shareDebtToken1;


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

// ---- Rules ------------------------------------------------------------------

// ---- Borrow -----------------------------------------------------------------
/// @title Integrity of borrow
/// @property borrow-integrity
rule HLP_integrityOfBorrow(address receiver, uint256 assets) {
    env e;

    // Block time-stamp >= interest rate time-stamp
    silosTimestampSetupRequirements(e);
    // Message sender is not one of the contracts in the scene
    nonSceneAddressRequirements(receiver);
    totalSuppliesMoreThanBalances(receiver, silo0);

    mathint balanceTokenBefore = token0.balanceOf(receiver);  
    mathint shareDebtTokenBefore = shareDebtToken0.balanceOf(receiver);  
       
    mathint shares = borrow(e, assets, receiver, receiver);

    mathint balanceTokenAfter = token0.balanceOf(receiver);  
    mathint shareDebtTokenAfter = shareDebtToken0.balanceOf(receiver);  
   
    assert (
        balanceTokenAfter == balanceTokenBefore + assets,
        "token balance increased appropriately"
    );
    assert (
        shareDebtTokenAfter == shareDebtTokenBefore + shares,
        "debt share increased appropriately"
    );
}


/// @title Integrity of `borrowSameAsset`
/// @property borrow-integrity
rule HLP_integrityOfBorrowSame(address receiver, uint256 assets) {
    env e;

    // Block time-stamp >= interest rate time-stamp
    silosTimestampSetupRequirements(e);
    // Message sender is not one of the contracts in the scene
    nonSceneAddressRequirements(receiver);
    totalSuppliesMoreThanBalances(receiver, silo0);

    mathint balanceTokenBefore = token0.balanceOf(receiver);  
    mathint shareDebtTokenBefore = shareDebtToken0.balanceOf(receiver);  
       
    mathint shares = borrowSameAsset(e, assets, receiver, receiver);

    mathint balanceTokenAfter = token0.balanceOf(receiver);  
    mathint shareDebtTokenAfter = shareDebtToken0.balanceOf(receiver);  

    assert (
        balanceTokenAfter == balanceTokenBefore + assets,
        "token balance increased appropriately"
    );
    assert (
        shareDebtTokenAfter == shareDebtTokenBefore + shares,
        "debt share increased appropriately"
    );
}
