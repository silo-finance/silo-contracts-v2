/* Third party protection rules (i.e. unrelated addresses are not affected)  */

import "../setup/CompleteSiloSetup.spec";
import "../simplifications/Silo_noAccrueInterest_simplification_UNSAFE.spec";
import "../simplifications/Oracle_quote_one_UNSAFE.spec";
import "../simplifications/SiloMathLib_SAFE.spec";

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

// ---- Deposit/Mint -----------------------------------------------------------

/// @title Deposit doesn't affect others
/// @property third-party
/// @status done
rule HLP_DepositDoesntAffectOthers(address receiver, address other, uint256 assets) {

    env e;
    require other != receiver && other != e.msg.sender;

    // Block time-stamp >= interest rate time-stamp
    silosTimestampSetupRequirements(e);
    // `other` is not one of the contracts in the scene
    nonSceneAddressRequirements(other);

    mathint balanceTokenBefore = token0.balanceOf(other);
    mathint balanceSharesBefore = shareDebtToken0.balanceOf(other);
    mathint balanceCollateralBefore = silo0.balanceOf(other);
    mathint balanceProtectedCollateralBefore = shareProtectedCollateralToken0.balanceOf(other);

    mathint shares = deposit(e, assets, receiver);

    mathint balanceTokenAfter = token0.balanceOf(other);
    mathint balanceSharesAfter = shareDebtToken0.balanceOf(other);
    mathint balanceCollateralAfter = silo0.balanceOf(other);
    mathint balanceProtectedCollateralAfter = shareProtectedCollateralToken0.balanceOf(other);

    assert balanceTokenBefore == balanceTokenAfter;
    assert balanceSharesBefore == balanceSharesAfter;
    assert balanceCollateralBefore == balanceCollateralAfter;
    assert balanceProtectedCollateralBefore == balanceProtectedCollateralAfter;
}


/// @title Mint doesn't affect others
/// @property third-party
/// @status done
rule HLP_MintDoesntAffectOthers(address receiver, address other, uint256 shares) {

    env e;
    require other != receiver && other != e.msg.sender;

    // Block time-stamp >= interest rate time-stamp
    silosTimestampSetupRequirements(e);
    // `other` is not one of the contracts in the scene
    nonSceneAddressRequirements(other);

    mathint balanceTokenBefore = token0.balanceOf(other);
    mathint balanceSharesBefore = shareDebtToken0.balanceOf(other);
    mathint balanceCollateralBefore = silo0.balanceOf(other);
    mathint balanceProtectedCollateralBefore = shareProtectedCollateralToken0.balanceOf(other);

    mathint assets = mint(e, shares, receiver);

    mathint balanceTokenAfter = token0.balanceOf(other);
    mathint balanceSharesAfter = shareDebtToken0.balanceOf(other);
    mathint balanceCollateralAfter = silo0.balanceOf(other);
    mathint balanceProtectedCollateralAfter = shareProtectedCollateralToken0.balanceOf(other);

    assert balanceTokenBefore == balanceTokenAfter;
    assert balanceSharesBefore == balanceSharesAfter;
    assert balanceCollateralBefore == balanceCollateralAfter;
    assert balanceProtectedCollateralBefore == balanceProtectedCollateralAfter;
}

// ---- Redeem/Withdraw --------------------------------------------------------

/// @title Redeem doesn't affect others
/// @property third-party
/// @status done
rule HLP_RedeemDoesntAffectOthers(address receiver, address other, uint256 shares) {

    env e;
    require other != receiver && other != e.msg.sender;

    // Block time-stamp >= interest rate time-stamp
    silosTimestampSetupRequirements(e);
    // `other` is not one of the contracts in the scene
    nonSceneAddressRequirements(other);

    mathint balanceTokenBefore = token0.balanceOf(other);
    mathint balanceSharesBefore = shareDebtToken0.balanceOf(other);
    mathint balanceCollateralBefore = silo0.balanceOf(other);
    mathint balanceProtectedCollateralBefore = shareProtectedCollateralToken0.balanceOf(other);

    mathint assets = redeem(e, shares, receiver, e.msg.sender);

    mathint balanceTokenAfter = token0.balanceOf(other);
    mathint balanceSharesAfter = shareDebtToken0.balanceOf(other);
    mathint balanceCollateralAfter = silo0.balanceOf(other);
    mathint balanceProtectedCollateralAfter = shareProtectedCollateralToken0.balanceOf(other);

    assert balanceTokenBefore == balanceTokenAfter;
    assert balanceSharesBefore == balanceSharesAfter;
    assert balanceCollateralBefore == balanceCollateralAfter;
    assert balanceProtectedCollateralBefore == balanceProtectedCollateralAfter;
}


/// @title Withdraw doesn't affect others
/// @property third-party
/// @status done
rule HLP_WithdrawDoesntAffectOthers(address receiver, address other, uint256 assets) {
    env e;
    require other != receiver && other != e.msg.sender;

    // Block time-stamp >= interest rate time-stamp
    silosTimestampSetupRequirements(e);
    // `other` is not one of the contracts in the scene
    nonSceneAddressRequirements(other);

    mathint balanceTokenBefore = token0.balanceOf(other);
    mathint balanceSharesBefore = shareDebtToken0.balanceOf(other);
    mathint balanceCollateralBefore = silo0.balanceOf(other);
    mathint balanceProtectedCollateralBefore = shareProtectedCollateralToken0.balanceOf(other);

    mathint shares = withdraw(e, assets, receiver, e.msg.sender);

    mathint balanceTokenAfter = token0.balanceOf(other);
    mathint balanceSharesAfter = shareDebtToken0.balanceOf(other);
    mathint balanceCollateralAfter = silo0.balanceOf(other);
    mathint balanceProtectedCollateralAfter = shareProtectedCollateralToken0.balanceOf(other);

    assert balanceTokenBefore == balanceTokenAfter;
    assert balanceSharesBefore == balanceSharesAfter;
    assert balanceCollateralBefore == balanceCollateralAfter;
    assert balanceProtectedCollateralBefore == balanceProtectedCollateralAfter;
}

// ---- Transition -------------------------------------------------------------

/// @title Transitioning collateral between protected an borrowable doesn't affect others
/// @property third-party
/// @status done
rule HLP_transitionCollateralDoesntAffectOthers(
    address receiver,
    address other,
    uint256 shares,
    ISilo.CollateralType anyType
) {
    env e;
    require other != receiver && other != e.msg.sender;

    // Block time-stamp >= interest rate time-stamp
    silosTimestampSetupRequirements(e);
    // `other` is not one of the contracts in the scene
    nonSceneAddressRequirements(other);

    mathint balanceTokenBefore = token0.balanceOf(other);
    mathint balanceSharesBefore = shareDebtToken0.balanceOf(other);
    mathint balanceCollateralBefore = silo0.balanceOf(other);
    mathint balanceProtectedCollateralBefore = shareProtectedCollateralToken0.balanceOf(other);

    mathint assets = transitionCollateral(e, shares, e.msg.sender, anyType);

    mathint balanceTokenAfter = token0.balanceOf(other);
    mathint balanceSharesAfter = shareDebtToken0.balanceOf(other);
    mathint balanceCollateralAfter = silo0.balanceOf(other);
    mathint balanceProtectedCollateralAfter = shareProtectedCollateralToken0.balanceOf(other);

    assert balanceTokenBefore == balanceTokenAfter;
    assert balanceSharesBefore == balanceSharesAfter;
    assert balanceCollateralBefore == balanceCollateralAfter;
    assert balanceProtectedCollateralBefore == balanceProtectedCollateralAfter;
}

// ---- Borrow -----------------------------------------------------------------

/// @title Borrow doesn't affect others
/// @property third-party
/// @status done
rule HLP_borrowDoesntAffectOthers(address receiver, address other, uint256 assets) {
    env e;
    require other != receiver && other != e.msg.sender;

    // Block time-stamp >= interest rate time-stamp
    silosTimestampSetupRequirements(e);
    // `other` is not one of the contracts in the scene
    nonSceneAddressRequirements(other);

    mathint balanceTokenBefore = token0.balanceOf(other);
    mathint balanceSharesBefore = shareDebtToken0.balanceOf(other);
    mathint balanceCollateralBefore = silo0.balanceOf(other);
    mathint balanceProtectedCollateralBefore = shareProtectedCollateralToken0.balanceOf(other);

    mathint shares = borrow(e, assets, receiver, e.msg.sender);

    mathint balanceTokenAfter = token0.balanceOf(other);
    mathint balanceSharesAfter = shareDebtToken0.balanceOf(other);
    mathint balanceCollateralAfter = silo0.balanceOf(other);
    mathint balanceProtectedCollateralAfter = shareProtectedCollateralToken0.balanceOf(other);

    assert balanceTokenBefore == balanceTokenAfter;
    assert balanceSharesBefore == balanceSharesAfter;
    assert balanceCollateralBefore == balanceCollateralAfter;
    assert balanceProtectedCollateralBefore == balanceProtectedCollateralAfter;
}


rule HLP_borrowRequiresAllowance(address receiver, address borrower, uint256 assets) 
{
    env e;
    SafeAssumptions_withInvariants(e, borrower);
    //silosTimestampSetupRequirements(e);
    nonSceneAddressRequirements(borrower);

    mathint balanceTokenBefore = token0.balanceOf(borrower);
    mathint balanceSharesBefore = shareDebtToken0.balanceOf(borrower);
    mathint balanceCollateralBefore = silo0.balanceOf(borrower);
    mathint balanceProtectedCollateralBefore = shareProtectedCollateralToken0.balanceOf(borrower);
    mathint allowanceBefore = shareDebtToken0.receiveAllowance(e, e.msg.sender, borrower);
    
    mathint shares = borrow(e, assets, receiver, borrower);

    mathint balanceTokenAfter = token0.balanceOf(borrower);
    mathint balanceSharesAfter = shareDebtToken0.balanceOf(borrower);
    mathint balanceCollateralAfter = silo0.balanceOf(borrower);
    mathint balanceProtectedCollateralAfter = shareProtectedCollateralToken0.balanceOf(borrower);
    mathint allowanceAfter = shareDebtToken0.receiveAllowance(e, e.msg.sender, borrower);

    assert borrower != e.msg.sender => allowanceBefore >= shares;
    assert borrower != e.msg.sender => allowanceAfter == allowanceBefore - shares;    //violated https://prover.certora.com/output/6893/3390feb0cb2a47b2bcda188d39997467/
    assert balanceTokenBefore <= balanceTokenAfter; //can go up if the receiver is the same as borrower
    assert balanceSharesBefore + shares == balanceSharesAfter;
    assert balanceCollateralBefore == balanceCollateralAfter;
    assert balanceProtectedCollateralBefore == balanceProtectedCollateralAfter;
}


/// @title Borrow same asset doesn't affect others
/// @property third-party
/// @status done
rule HLP_borrowSameAssetDoesntAffectOthers(address receiver, address other, uint256 assets) {
    env e;
    require other != receiver && other != e.msg.sender;

    // Block time-stamp >= interest rate time-stamp
    silosTimestampSetupRequirements(e);
    // `other` is not one of the contracts in the scene
    nonSceneAddressRequirements(other);

    mathint balanceTokenBefore = token0.balanceOf(other);
    mathint balanceSharesBefore = shareDebtToken0.balanceOf(other);
    mathint balanceCollateralBefore = silo0.balanceOf(other);
    mathint balanceProtectedCollateralBefore = shareProtectedCollateralToken0.balanceOf(other);

    mathint shares = borrowSameAsset(e, assets, receiver, e.msg.sender);

    mathint balanceTokenAfter = token0.balanceOf(other);
    mathint balanceSharesAfter = shareDebtToken0.balanceOf(other);
    mathint balanceCollateralAfter = silo0.balanceOf(other);
    mathint balanceProtectedCollateralAfter = shareProtectedCollateralToken0.balanceOf(other);

    assert balanceTokenBefore == balanceTokenAfter;
    assert balanceSharesBefore == balanceSharesAfter;
    assert balanceCollateralBefore == balanceCollateralAfter;
    assert balanceProtectedCollateralBefore == balanceProtectedCollateralAfter;
}


/// @title Borrow shares doesn't affect others
/// @property third-party
/// @status done
rule HLP_borrowSharesDoesntAffectOthers(address receiver, address other, uint256 shares) {

    env e;
    require other != receiver && other != e.msg.sender;

    // Block time-stamp >= interest rate time-stamp
    silosTimestampSetupRequirements(e);
    // `other` is not one of the contracts in the scene
    nonSceneAddressRequirements(other);

    mathint balanceTokenBefore = token0.balanceOf(other);
    mathint balanceSharesBefore = shareDebtToken0.balanceOf(other);
    mathint balanceCollateralBefore = silo0.balanceOf(other);
    mathint balanceProtectedCollateralBefore = shareProtectedCollateralToken0.balanceOf(other);

    mathint assets = borrowShares(e, shares, receiver, e.msg.sender);

    mathint balanceTokenAfter = token0.balanceOf(other);
    mathint balanceSharesAfter = shareDebtToken0.balanceOf(other);
    mathint balanceCollateralAfter = silo0.balanceOf(other);
    mathint balanceProtectedCollateralAfter = shareProtectedCollateralToken0.balanceOf(other);

    assert balanceTokenBefore == balanceTokenAfter;
    assert balanceSharesBefore == balanceSharesAfter;
    assert balanceCollateralBefore == balanceCollateralAfter;
    assert balanceProtectedCollateralBefore == balanceProtectedCollateralAfter;
}

// ---- Repay ------------------------------------------------------------------

/// @title Repay doesn't affect others
/// @property third-party
/// @status done
rule HLP_repayDoesntAffectOthers(address receiver, address other, uint256 assets) {
    env e;
    require other != receiver && other != e.msg.sender;

    // Block time-stamp >= interest rate time-stamp
    silosTimestampSetupRequirements(e);
    // `other` is not one of the contracts in the scene
    nonSceneAddressRequirements(other);

    mathint balanceTokenBefore = token0.balanceOf(other);
    mathint balanceSharesBefore = shareDebtToken0.balanceOf(other);
    mathint balanceCollateralBefore = silo0.balanceOf(other);
    mathint balanceProtectedCollateralBefore = shareProtectedCollateralToken0.balanceOf(other);

    mathint shares = repay(e, assets, e.msg.sender);

    mathint balanceTokenAfter = token0.balanceOf(other);
    mathint balanceSharesAfter = shareDebtToken0.balanceOf(other);
    mathint balanceCollateralAfter = silo0.balanceOf(other);
    mathint balanceProtectedCollateralAfter = shareProtectedCollateralToken0.balanceOf(other);

    assert balanceTokenBefore == balanceTokenAfter;
    assert balanceSharesBefore == balanceSharesAfter;
    assert balanceCollateralBefore == balanceCollateralAfter;
    assert balanceProtectedCollateralBefore == balanceProtectedCollateralAfter;
}


/// @title Repay shares doesn't affect others
/// @property third-party
/// @status done
rule HLP_repaySharesDoesntAffectOthers(address receiver, address other, uint256 shares) {

    env e;
    require other != receiver && other != e.msg.sender;

    // Block time-stamp >= interest rate time-stamp
    silosTimestampSetupRequirements(e);
    // `other` is not one of the contracts in the scene
    nonSceneAddressRequirements(other);

    mathint balanceTokenBefore = token0.balanceOf(other);
    mathint balanceSharesBefore = shareDebtToken0.balanceOf(other);
    mathint balanceCollateralBefore = silo0.balanceOf(other);
    mathint balanceProtectedCollateralBefore = shareProtectedCollateralToken0.balanceOf(other);

    mathint assets = repayShares(e, shares, e.msg.sender);

    mathint balanceTokenAfter = token0.balanceOf(other);
    mathint balanceSharesAfter = shareDebtToken0.balanceOf(other);
    mathint balanceCollateralAfter = silo0.balanceOf(other);
    mathint balanceProtectedCollateralAfter = shareProtectedCollateralToken0.balanceOf(other);

    assert balanceTokenBefore == balanceTokenAfter;
    assert balanceSharesBefore == balanceSharesAfter;
    assert balanceCollateralBefore == balanceCollateralAfter;
    assert balanceProtectedCollateralBefore == balanceProtectedCollateralAfter;
}
