import "../summaries/two_silos_summaries.spec";
import "../summaries/siloconfig_dispatchers.spec";
import "../summaries/tokens_dispatchers.spec";
import "../summaries/sound.spec";  // safe-approximations

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

// ---- Borrow -----------------------------------------------------------------

/// @title Integrity of borrow
/// @property borrow-integrity
/// @status Done
rule HLP_integrityOfBorrow(address receiver, uint256 assets) {
    env e;

    // Block time-stamp >= interest rate time-stamp
    silosTimestampSetupRequirements(e);
    // receiver is not one of the contracts in the scene
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
/// @status Done
rule HLP_integrityOfBorrowSame(address receiver, uint256 assets) {
    env e;

    // Block time-stamp >= interest rate time-stamp
    silosTimestampSetupRequirements(e);
    // receiver is not one of the contracts in the scene
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


/// @title Integrity of `borrowShares`
/// @property borrow-integrity
/// @status Done
rule HLP_integrityOfBorrowShares(address receiver, uint256 shares) {
    env e;

    // Block time-stamp >= interest rate time-stamp
    silosTimestampSetupRequirements(e);
    // receiver is not one of the contracts in the scene
    nonSceneAddressRequirements(receiver);
    totalSuppliesMoreThanBalances(receiver, silo0);
    
    mathint balanceTokenBefore = token0.balanceOf(receiver);  
    mathint shareDebtTokenBefore = shareDebtToken0.balanceOf(receiver);  
       
    mathint assets = borrowShares(e, shares, receiver, receiver);

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

// ---- Deposit/Mint -----------------------------------------------------------

/// @title Integrity of deposit
rule HLP_integrityOfDeposit(address receiver, uint256 assets) {
    env e;

    // Block time-stamp >= interest rate time-stamp
    silosTimestampSetupRequirements(e);
    // receiver is not one of the contracts in the scene
    nonSceneAddressRequirements(receiver);
    require e.msg.sender != silo0;

    totalSuppliesMoreThanBalances(receiver, silo0);

    mathint balanceCollateralBefore = silo0.balanceOf(receiver);
    mathint balanceTokenBefore = token0.balanceOf(e.msg.sender);  
    
    mathint shares = deposit(e, assets, receiver);

    mathint balanceCollateralAfter = silo0.balanceOf(receiver);  
    mathint balanceTokenAfter = token0.balanceOf(e.msg.sender);  

    assert (shares > 0, "non-zero shares");
    assert (
        balanceCollateralAfter == balanceCollateralBefore + shares,
        "collateral shares increased by deposit"
    );
    assert (
        balanceTokenAfter == balanceTokenBefore - assets,
        "token balance decreased by deposit"
    );
}


/// @title Integrity of mint
rule HLP_integrityOfMint(address receiver, uint256 shares) {
    env e;

    // Block time-stamp >= interest rate time-stamp
    silosTimestampSetupRequirements(e);
    // receiver is not one of the contracts in the scene
    nonSceneAddressRequirements(receiver);
    require e.msg.sender != silo0;
    
    totalSuppliesMoreThanBalances(receiver, silo0);
    
    mathint balanceCollateralBefore = silo0.balanceOf(receiver);
    mathint balanceTokenBefore = token0.balanceOf(e.msg.sender);  
        
    mathint assets = mint(e, shares, receiver);

    mathint balanceCollateralAfter = silo0.balanceOf(receiver);  
    mathint balanceTokenAfter = token0.balanceOf(e.msg.sender);  
   
    assert (
        balanceCollateralAfter == balanceCollateralBefore + shares,
        "collateral shares increased by mint"
    );
    assert (
        balanceTokenAfter == balanceTokenBefore - assets,
        "token balance decreased by mmint"
    );
}

// ---- Redeem/Withdraw --------------------------------------------------------

/// @title Integrity of redeem
rule HLP_integrityOfRedeem(address receiver, uint256 shares) {
    env e;

    // Block time-stamp >= interest rate time-stamp
    silosTimestampSetupRequirements(e);
    // receiver is not one of the contracts in the scene
    nonSceneAddressRequirements(receiver);
    totalSuppliesMoreThanBalances(receiver, silo0);
    
    mathint balanceCollateralBefore = silo0.balanceOf(receiver);
    mathint balanceTokenBefore = token0.balanceOf(receiver);  
        
    mathint assets = redeem(e, shares, receiver, receiver);

    mathint balanceCollateralAfter = silo0.balanceOf(receiver);  
    mathint balanceTokenAfter = token0.balanceOf(receiver);  
   
    assert balanceCollateralAfter == balanceCollateralBefore - shares;
    assert balanceTokenAfter == balanceTokenBefore + assets;
}


/// @title Integrity of withdraw
rule HLP_integrityOfWithdraw(address receiver, uint256 assets) {
    env e;

    // Block time-stamp >= interest rate time-stamp
    silosTimestampSetupRequirements(e);
    // receiver is not one of the contracts in the scene
    nonSceneAddressRequirements(receiver);
    totalSuppliesMoreThanBalances(receiver, silo0);
    
    mathint balanceCollateralBefore = silo0.balanceOf(receiver);
    mathint balanceTokenBefore = token0.balanceOf(receiver);    

    mathint shares = withdraw(e, assets, receiver, receiver);

    mathint balanceCollateralAfter = silo0.balanceOf(receiver);  
    mathint balanceTokenAfter = token0.balanceOf(receiver);
   
    assert balanceCollateralAfter == balanceCollateralBefore - shares;
    assert balanceTokenAfter == balanceTokenBefore + assets;
}

// ---- Repay ------------------------------------------------------------------

/// @title Integrity of `repay`
/// @property repay-integrity
rule HLP_integrityOfRepay(address receiver, uint256 assets) {
    env e;

    // Block time-stamp >= interest rate time-stamp
    silosTimestampSetupRequirements(e);
    // receiver is not one of the contracts in the scene
    nonSceneAddressRequirements(receiver);
    totalSuppliesMoreThanBalances(receiver, silo0);
    require receiver == e.msg.sender;
    
    mathint balanceTokenBefore = token0.balanceOf(receiver);  
    mathint shareDebtTokenBefore = shareDebtToken0.balanceOf(receiver);  
       
    mathint shares = repay(e, assets, receiver);

    mathint balanceTokenAfter = token0.balanceOf(receiver);  
    mathint shareDebtTokenAfter = shareDebtToken0.balanceOf(receiver);  
   
    assert balanceTokenAfter == balanceTokenBefore - assets;
    assert shareDebtTokenAfter == shareDebtTokenBefore - shares;
}


/// @title Integrity of `repayShares`
/// @property repay-integrity
rule HLP_integrityOfRepayShares(address receiver, uint256 shares) {
    env e;

    // Block time-stamp >= interest rate time-stamp
    silosTimestampSetupRequirements(e);
    // receiver is not one of the contracts in the scene
    nonSceneAddressRequirements(receiver);
    totalSuppliesMoreThanBalances(receiver, silo0);
    require receiver == e.msg.sender;

    mathint balanceTokenBefore = token0.balanceOf(receiver);  
    mathint shareDebtTokenBefore = shareDebtToken0.balanceOf(receiver);  
       
    mathint assets = repayShares(e, shares, receiver);

    mathint balanceTokenAfter = token0.balanceOf(receiver);  
    mathint shareDebtTokenAfter = shareDebtToken0.balanceOf(receiver);  
   
    assert balanceTokenAfter == balanceTokenBefore - assets;
    assert shareDebtTokenAfter == shareDebtTokenBefore - shares;
}
