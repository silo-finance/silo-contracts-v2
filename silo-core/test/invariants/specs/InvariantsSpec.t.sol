// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title InvariantsSpec
/// @notice Invariants specification for the protocol
/// @dev Contains pseudo code and description for the invariant properties in the protocol
abstract contract InvariantsSpec {
    /*/////////////////////////////////////////////////////////////////////////////////////////////
    //                                      PROPERTY TYPES                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// - INVARIANTS (INV): 
    ///   - Properties that should always hold true in the system. 
    ///   - Implemented in the /invariants folder.

    /////////////////////////////////////////////////////////////////////////////////////////////*/

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          BASE                                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          SILO ROUTER                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant ROUTER_INVARIANT_A = "ROUTER_INVARIANT_A: Router ETH balance should always be 0 after function execution"; //custom

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          BASE                                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant BASE_INVARIANT_A = "BASE_INVARIANT_A: reentrancyLock == REENTRANCY_UNLOCKED";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       SILO MARKET                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant SILO_INVARIANT_A = "SILO_INVARIANT_A: Protected collateral (totalAssets[0])"; //TODO: Pending

    string constant SILO_INVARIANT_B = "SILO_INVARIANT_B: Protected collateral should be always withdrawable to the fullest"; //custom

    string constant SILO_INVARIANT_C = "SILO_INVARIANT_C: Protected collateral total(totalAssets[0])"; //TODO: Pending

    string constant SILO_INVARIANT_D = "SILO_INVARIANT_D: User must not have debt in more than 1 silo at the same time"; //custom

    string constant SILO_INVARIANT_E = "SILO_INVARIANT_E: When interestRateTimestamp = block.timestamp, totalAssets[COLLATERAL] & totalAssets[DEBT] MUST NOT increase "; //custom

    string constant SILO_INVARIANT_F = "SILO_INVARIANT_F: Balance after flashloaning a token needs to be => that the initial balance of such token + the flash fee for such amount"; //custom

    string constant SILO_INVARIANT_G = "SILO_INVARIANT_G: _debtShareToken totalsupply MUST increase while borrowing"; //custom

    string constant SILO_INVARIANT_H = "SILO_INVARIANT_H: _debtShareToken totalsupply MUST decrease on repayments"; //custom

    string constant SILO_INVARIANT_I = "SILO_INVARIANT_I: _debtShareToken totalSupply MUST be the sum of all borrowed shares"; //custom

    string constant SILO_INVARIANT_J = "SILO_INVARIANT_J: _collateralShareToken balance MUST increase while depositing"; //custom

    string constant SILO_INVARIANT_K = "SILO_INVARIANT_K: _collateralShareToken balance MUST decrease while withdrawing"; //custom

    string constant SILO_INVARIANT_L = "SILO_INVARIANT_L: _collateralShareToken totalSupply MUST be the sum of all deposited shares"; //custom

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                              SILO MODULE ERC4626 INVARIANTS                               //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice ASSETS

    string constant ERC4626_ASSETS_INVARIANT_A = "ERC4626_ASSETS_INVARIANT_A: asset MUST NOT revert";

    string constant ERC4626_ASSETS_INVARIANT_B = "ERC4626_ASSETS_INVARIANT_B: totalAssets MUST NOT revert";

    string constant ERC4626_ASSETS_INVARIANT_C = "ERC4626_ASSETS_INVARIANT_C: convertToShares MUST NOT show any variations depending on the caller";

    string constant ERC4626_ASSETS_INVARIANT_D = "ERC4626_ASSETS_INVARIANT_D: convertToAssets MUST NOT show any variations depending on the caller";

    /// @notice DEPOSIT

    string constant ERC4626_DEPOSIT_INVARIANT_A = "ERC4626_DEPOSIT_INVARIANT_A: maxDeposit MUST NOT revert";

    string constant ERC4626_DEPOSIT_INVARIANT_B = "ERC4626_DEPOSIT_INVARIANT_B: previewDeposit MUST return close to and no more than shares minted at deposit if called in the same transaction";

    /// @notice MINT

    string constant ERC4626_MINT_INVARIANT_A = "ERC4626_MINT_INVARIANT_A: maxMint MUST NOT revert";

    string constant ERC4626_MINT_INVARIANT_B = "ERC4626_MINT_INVARIANT_B: previewMint MUST return close to and no fewer than assets deposited at mint if called in the same transaction";

    /// @notice WITHDRAW

    string constant ERC4626_WITHDRAW_INVARIANT_A = "ERC4626_WITHDRAW_INVARIANT_A: maxWithdraw MUST NOT revert";

    string constant ERC4626_WITHDRAW_INVARIANT_B = "ERC4626_WITHDRAW_INVARIANT_B: previewWithdraw MUST return close to and no fewer than shares burned at withdraw if called in the same transaction";

    /// @notice REDEEM

    string constant ERC4626_REDEEM_INVARIANT_A = "ERC4626_REDEEM_INVARIANT_A: maxRedeem MUST NOT revert";

    string constant ERC4626_REDEEM_INVARIANT_B = "ERC4626_REDEEM_INVARIANT_B: previewRedeem MUST return close to and no more than assets redeemed at redeem if called in the same transaction";

    /// @notice ROUNDTRIP

    string constant ERC4626_ROUNDTRIP_INVARIANT_A = "ERC4626_ROUNDTRIP_INVARIANT_A: redeem(deposit(a)) <= a";

    string constant ERC4626_ROUNDTRIP_INVARIANT_B = "ERC4626_ROUNDTRIP_INVARIANT_B: s = deposit(a) s' = withdraw(a) s' >= s";

    string constant ERC4626_ROUNDTRIP_INVARIANT_C = "ERC4626_ROUNDTRIP_INVARIANT_C: deposit(redeem(s)) <= s";

    string constant ERC4626_ROUNDTRIP_INVARIANT_D = "ERC4626_ROUNDTRIP_INVARIANT_D: a = redeem(s) a' = mint(s) a' >= a";

    string constant ERC4626_ROUNDTRIP_INVARIANT_E = "ERC4626_ROUNDTRIP_INVARIANT_E: withdraw(mint(s)) >= s";

    string constant ERC4626_ROUNDTRIP_INVARIANT_F = "ERC4626_ROUNDTRIP_INVARIANT_F: a = mint(s) a' = redeem(s) a' <= a";

    string constant ERC4626_ROUNDTRIP_INVARIANT_G = "ERC4626_ROUNDTRIP_INVARIANT_G: mint(withdraw(a)) >= a";

    string constant ERC4626_ROUNDTRIP_INVARIANT_H = "ERC4626_ROUNDTRIP_INVARIANT_H: s = withdraw(a) s' = deposit(a) s' <= s";

    //TODO need to move invariants from SILO Market above to here and overall re-structure

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                     BORROWING MODULE SILO                                 //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant BM_INVARIANT_A = "BM_INVARIANT_A: totalBorrowed >= any account owed balance";

    string constant BM_INVARIANT_B = "BM_INVARIANT_B: totalBorrowed = sum of all user debt";

    string constant BM_INVARIANT_C = "BM_INVARIANT_C: sum of all user debt == 0 <=> totalBorrowed == 0";

    string constant BM_INVARIANT_D = "BM_INVARIANT_D: User liability should always decrease after repayment";

    string constant BM_INVARIANT_E = "BM_INVARIANT_E: Unhealthy users can not borrow";

    string constant BM_INVARIANT_F = "BM_INVARIANT_F: "; //EMPTY

    string constant BM_INVARIANT_G = "BM_INVARIANT_G: a user should always be able to withdraw all if there is no outstanding debt";

    string constant BM_INVARIANT_H = "BM_INVARIANT_H: If totalBorrows increases new totalBorrows must be less than or equal to borrow cap";

    string constant BM_INVARIANT_I = "BM_INVARIANT_I: "; //EMPTY

    string constant BM_INVARIANT_J = "BM_INVARIANT_J: "; //EMPTY

    string constant BM_INVARIANT_K = "BM_INVARIANT_K: Functions that won't operate when user is unhealthy";

    string constant BM_INVARIANT_L = "BM_INVARIANT_L: Functions that can operate when user is unhealthy";

    string constant BM_INVARIANT_M = ""; //EMPTY

    string constant BM_INVARIANT_N1 = "BM_INVARIANT_N1: borrow/deposit(x) => repay(x) users shouldn't gain any asset"; //NOT SURE RENAMED

    string constant BM_INVARIANT_N2 = "BM_INVARIANT_N2: borrow/deposit(x) => repay(x) users debt shouldn't decrease"; //NOT SURE RENAMED

    string constant BM_INVARIANT_O = "BM_INVARIANT_O: debt(user) != 0 => collateralValue != 0"; //TODO: REMAKE, DEBT IS BALANCE OF _debtShareToken OF BORROWER

    string constant BM_INVARIANT_P = "BM_INVARIANT_P: a user can always repay debt in full";
}
