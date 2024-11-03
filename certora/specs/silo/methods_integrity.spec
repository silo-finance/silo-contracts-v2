/* Integrity of main methods */

import "../summaries/two_silos_summaries.spec";
import "../summaries/siloconfig_dispatchers.spec";
import "../summaries/tokens_dispatchers.spec";
import "../summaries/erc20_in_cvl.spec";
import "../summaries/safe-approximations.spec";

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
/// @status Done: https://vaas-stg.certora.com/output/39601/a92223ffd54b428bbc75fbbf76deaa91?anonymousKey=f962f690a342ccff3b3843c47f2d310b98d355f6
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
/// @status Done: https://vaas-stg.certora.com/output/39601/0c5fdd83985f4cff92e256770d4a2146?anonymousKey=3d525a9323f55a52a02015eef18222af0a30e531
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
/// @status Done: https://vaas-stg.certora.com/output/39601/ba5142728e9e4089a74f3a448e4df9fa?anonymousKey=c6c5cca56df4b25896022089b307da711046c6c8
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
/// @status Done: https://vaas-stg.certora.com/output/39601/6a9f19160e884c9991fc0e9adb51afac?anonymousKey=bffdda9bd17af80e1aa274b70bafa2fe2acfc1a6
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
/// @status: Done https://vaas-stg.certora.com/output/39601/cfafce63b506448bb331bde0ce2d4638?anonymousKey=8982d16e1772dc713a388095c653324a1095f0e7
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
/// @status: Done https://vaas-stg.certora.com/output/39601/d6ba40df683a417582b99a4a07996c80?anonymousKey=a34896d77cf347614a5969668dd17843bf53b089
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
/// @status Done: https://vaas-stg.certora.com/output/39601/fe9d02f2d8c641329304f04e7b32c155?anonymousKey=6684f7a4cb199e09e5a579aaa3870094b3767cda
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
/// @status Done: https://vaas-stg.certora.com/output/39601/e06d1ce059bf4da89811b85e27222a09?anonymousKey=30d61e965cc82a02174cef508c00afab78442e3a
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
/// @status Done: https://vaas-stg.certora.com/output/39601/e7313b4bb45845aab4588d37aab94e8e?anonymousKey=7e146049c5620d5a31f23fb14995b94c756698ea
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
